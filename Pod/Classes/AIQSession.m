#import "AFHTTPRequestOperationManager.h"
#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "FMDBMigrationManager.h"
#import "SessionProperties.h"

NSString *const kAIQUserInfo = @"AIQUserInfo";
NSString *const kAIQUserEmail = @"AIQUserEmail";
NSString *const kAIQUserFullName = @"AIQUserFullName";
NSString *const kAIQUserGroups = @"AIQUserGroups";
NSString *const kAIQUserName = @"AIQUserName";
NSString *const kAIQUserPermissions = @"AIQUserPermissions";
NSString *const kAIQUserProfile = @"AIQUserProfile";
NSString *const kAIQUserRoles = @"AIQUserRoles";

NSString *const kAIQSessionPropertiesRoot = @"AIQSessionPropertiesRoot";
NSString *const kAIQSessionCurrentSessionKey = @"AIQSessionCurrentSessionKey";
NSString *const kAIQSessionKnownSessions = @"AIQSessionKnownSessions";

NSString *const kAIQSessionBaseURL = @"AIQSessionBaseURL";
NSString *const kAIQSessionAccessToken = @"AIQSessionAccessToken";
NSString *const kAIQSessionLogoutUrl = @"AIQSessionLogoutUrl";
NSString *const kAIQSessionCOMessageUrl = @"AIQSessionCOMessageUrl";
NSString *const kAIQSessionDirectUrl = @"AIQSessionDirectUrl";
NSString *const kAIQSessionStartDataSyncUrl = @"AIQSessionStartDataSyncUrl";
NSString *const kAIQSessionDownloadUrl = @"AIQSessionDownloadUrl";
NSString *const kAIQSessionUploadUrl = @"AIQSessionUploadUrl";
NSString *const kAIQSessionAttachmentsUrl = @"AIQSessionAttachmentsUrl";
NSString *const kAIQSessionPushUrl = @"AIQSessionPushUrl";

AIQSession *currentSession;

@interface AIQDataStore ()

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution;

@end

@interface AIQSynchronization ()

- (instancetype)initForSession:(AIQSession *)session;
- (void)close;

@end

@interface AIQSession () {
    AFHTTPRequestOperationManager *_manager;
    AIQSynchronization *_synchronization;
    BOOL _isOpen;
    NSString *_sessionKey;
    NSMutableDictionary *_properties;
    NSString *_basePath;
    NSString *_dbPath;
}

@end

@implementation AIQSession

+ (instancetype)currentSession {
    return currentSession;
}

+ (BOOL)canResume {
    if (currentSession) {
        return NO;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *root = [defaults dictionaryForKey:kAIQSessionPropertiesRoot];
    if (! root) {
        return NO;
    }
    
    NSString *sessionKey = root[kAIQSessionCurrentSessionKey];
    if (! sessionKey) {
        return NO;
    }
    
    NSDictionary *knownSessions = root[kAIQSessionKnownSessions];
    if (! knownSessions) {
        return NO;
    }
    
    return knownSessions[sessionKey] != nil;
}

+ (instancetype)resume:(NSError *__autoreleasing *)error {
    if (currentSession) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session already open"];
        }
        return nil;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *root = [defaults dictionaryForKey:kAIQSessionPropertiesRoot];
    if (! root) {
        return nil;
    }
    
    NSString *sessionKey = root[kAIQSessionCurrentSessionKey];
    if (! sessionKey) {
        return nil;
    }
    
    NSDictionary *knownSessions = root[kAIQSessionKnownSessions];
    if (! knownSessions) {
        return nil;
    }
    
    NSDictionary *properties = knownSessions[sessionKey];
    if (! properties) {
        return nil;
    }
    
    AIQSession *session = [AIQSession sessionWithBaseURL:[NSURL URLWithString:properties[kAIQSessionBaseURL]]];
    NSError *localError = nil;
    if (! [session prepareDatabase:&localError]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
        }
        return nil;
    }
    
    [session setValue:sessionKey forKey:@"sessionKey"];
    [session setValue:[properties mutableCopy] forKey:@"properties"];
    [session authorizeManager];
    [session setValue:@YES forKey:@"isOpen"];
    
    currentSession = session;
    
    return session;
}

+ (instancetype)sessionWithBaseURL:(NSURL *)url {
    if (! url) {
        return nil;
    }
    
    return [[AIQSession alloc] initWithBaseURL:url];
}

- (void)openForUser:(NSString *)username
           password:(NSString *)password
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {
    [self openForUser:username password:password info:nil inOrganization:organization success:success failure:failure];
}

- (void)openForUser:(NSString *)username
           password:(NSString *)password
               info:(NSDictionary *)info
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {
    
    if (_isOpen) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session already open"]);
        }
        return;
    }
    
    if (! username) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Username not specified"]);
        }
        return;
    }
    
    if (! password) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Password not specified"]);
        }
        return;
    }
    
    if (! organization) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Organization not specified"]);
        }
        return;
    }
    
    [_manager GET:@"/api" parameters:@{@"orgName": organization} success:^(id operation, NSDictionary *json) {
        NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
        parameters[@"grant_type"] = @"password";
        parameters[@"username"] = username;
        parameters[@"password"] = password;
        parameters[@"x-deviceId"] = [[NSUUID UUID] UUIDString];
        
        if (info) {
            for (NSString *key in info) {
                parameters[[NSString stringWithFormat:@"x-%@", key]] = info[key];
            }
        }
        
        [_manager POST:json[@"links"][@"token"] parameters:parameters success:^(id operation, NSDictionary *json) {
            _sessionKey = json[@"user"][@"_id"];

            NSError *error = nil;
            if ([self prepareDatabase:&error]) {
                [self copyProperties:json];
                [self authorizeManager];

                _isOpen = YES;
                
                [self storeSessionInfo];
                
                if (success) {
                    success();
                }
            } else if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:error.localizedDescription]);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self handleError:error callback:failure];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

- (void)close:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (! _isOpen) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session not open"]);
        }
        return;
    }
    
    [self removeSessionInfo];
    
    NSString *logout = _properties[kAIQSessionLogoutUrl];
    
    if (_synchronization) {
        [_synchronization close];
        _synchronization = nil;
    }
    
    _basePath = nil;
    _dbPath = nil;
    _isOpen = NO;
    _sessionKey = nil;
    _properties = nil;

    [_manager POST:logout parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

- (void)cancel {
    [_manager.operationQueue cancelAllOperations];
}

- (id)objectForKeyedSubscript:(NSString *)key {
    return _properties[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
    if (obj) {
        _properties[key] = obj;
    } else {
        [_properties removeObjectForKey:key];
    }
}

- (AIQDataStore *)dataStoreForSolution:(NSString *)solution {
    return [[AIQDataStore alloc] initForSession:self solution:solution];
}

- (AIQSynchronization *)synchronization {
    if (! _synchronization) {
        _synchronization = [[AIQSynchronization alloc] initForSession:self];
    }
    return _synchronization;
}

#pragma mark - Private API

- (instancetype)init {
    return nil;
}

- (instancetype)initWithBaseURL:(NSURL *)url {
    if (! url) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        _manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    return self;
}

- (void)handleError:(NSError *)error callback:(void (^)(NSError *))callback {
    NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
    if (response) {
        NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            NSInteger errorCode;
            NSString *errorKey = json[@"error"];
            NSString *messageKey = json[@"error_description"];
            if ([errorKey isEqualToString:@"not_found"]) {
                errorCode = AIQErrorInvalidArgument;
                if (! messageKey) {
                    messageKey = @"Organization not found";
                }
            } else if ([errorKey isEqualToString:@"invalid_grant"]) {
                errorCode = AIQErrorInvalidArgument;
                if (! messageKey) {
                    messageKey = @"Bad username and/or password";
                }
            } else {
                errorCode = error.code;
                messageKey = error.localizedDescription;
            }
            AIQLogCError(1, @"Did fail to authenticate: %@", messageKey);
            if (callback) {
                callback([AIQError errorWithCode:errorCode message:messageKey]);
            }
        } else {
            AIQLogCError(1, @"Did fail to authenticate: %ld", (unsigned long)response.statusCode);
            if (callback) {
                callback(error);
            }
        }
    } else {
        AIQLogCError(1, @"Did fail to authenticate: %@", error.localizedDescription);
        if (callback) {
            callback(error);
        }
    }
}

- (void)copyProperties:(NSDictionary *)json {
    _properties = [NSMutableDictionary dictionary];
    
    [self copyLinks:json];
    [self copyUserInfo:json];
    
    _properties[kAIQSessionAccessToken] = json[@"access_token"];
    _properties[kAIQSessionBaseURL] = _manager.baseURL.absoluteString;
}

- (void)copyLinks:(NSDictionary *)json {
    NSDictionary *links = json[@"links"];
    if (links[@"logout"]) {
        _properties[kAIQSessionLogoutUrl] = links[@"logout"];
    }
    if (links[@"startdatasync"]) {
        _properties[kAIQSessionStartDataSyncUrl] = links[@"startdatasync"];
    }
    if (links[@"comessage"]) {
        _properties[kAIQSessionCOMessageUrl] = links[@"comessage"];
    }
    if (links[@"direct"]) {
        _properties[kAIQSessionDirectUrl] = links[@"direct"];
    }
}

- (void)copyUserInfo:(NSDictionary *)json {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSDictionary *user = json[@"user"];
    
    if (user[@"email"]) {
        userInfo[kAIQUserEmail] = user[@"email"];
    }
    userInfo[kAIQUserFullName] = user[@"fullName"];
    userInfo[kAIQUserGroups] = user[@"groups"];
    userInfo[kAIQUserName] = user[@"username"];
    userInfo[kAIQUserPermissions] = user[@"permissions"];
    userInfo[kAIQUserProfile] = user[@"profile"];
    userInfo[kAIQUserRoles] = user[@"roles"];
    _properties[kAIQUserInfo] = [userInfo copy];
}

- (void)authorizeManager {
    [_manager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _properties[kAIQSessionAccessToken]] forHTTPHeaderField:@"Authorization"];
}

- (void)storeSessionInfo {
    [self storeProperties];
    
    currentSession = self;
}

- (void)removeSessionInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableDictionary *root = [[defaults dictionaryForKey:kAIQSessionPropertiesRoot] mutableCopy];
    
    [root removeObjectForKey:kAIQSessionCurrentSessionKey];
    
    NSMutableDictionary *knownSessions = [root[kAIQSessionKnownSessions] mutableCopy];
    [knownSessions removeObjectForKey:_sessionKey];
    root[kAIQSessionKnownSessions] = knownSessions;
    
    [defaults setValue:root forKey:kAIQSessionPropertiesRoot];
    [defaults synchronize];
    
    currentSession = nil;
}

- (void)storeProperties {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableDictionary *root;
    if ([defaults dictionaryForKey:kAIQSessionPropertiesRoot]) {
        root = [[defaults dictionaryForKey:kAIQSessionPropertiesRoot] mutableCopy];
    } else {
        root = [NSMutableDictionary dictionary];
    }
    
    root[kAIQSessionCurrentSessionKey] = _sessionKey;
    
    NSMutableDictionary *knownSessions;
    if (root[kAIQSessionKnownSessions]) {
        knownSessions = [root[kAIQSessionKnownSessions] mutableCopy];
    } else {
        knownSessions = [NSMutableDictionary dictionary];
    }
    knownSessions[_sessionKey] = _properties;
    root[kAIQSessionKnownSessions] = knownSessions;
    
    [defaults setValue:root forKey:kAIQSessionPropertiesRoot];
    [defaults synchronize];
}

- (BOOL)prepareDatabase:(NSError *__autoreleasing *)error {
    _basePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    _basePath = [_basePath stringByAppendingPathComponent:_sessionKey];
    _dbPath = [_basePath stringByAppendingPathComponent:@"data.sqlite"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (! [fileManager fileExistsAtPath:_basePath isDirectory:nil]) {
        if (! [fileManager createDirectoryAtPath:_basePath
                     withIntermediateDirectories:YES
                                      attributes:@{NSFileProtectionKey: NSFileProtectionComplete}
                                           error:error]) {
            return NO;
        }
    }
    
    NSBundle *migrationBundle = [NSBundle bundleForClass:[AIQSession class]];
    FMDBMigrationManager *manager = [FMDBMigrationManager managerWithDatabaseAtPath:_dbPath migrationsBundle:migrationBundle];
    if (! [manager hasMigrationsTable]) {
        if (! [manager createMigrationsTable:error]) {
            return NO;
        }
    }
    
    if ([manager needsMigration]) {
        if (! [manager migrateDatabaseToVersion:UINT64_MAX progress:nil error:error]) {
            return NO;
        }
    }
    
    return YES;
}

@end
