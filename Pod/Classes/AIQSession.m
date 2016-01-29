#import <Foundation/Foundation.h>
#import <FMDBMigrationManager/FMDBMigrationManager.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "AIQContext.h"
#import "AIQContextSynchronizer.h"
#import "AIQCoreLibInternal.h"
#import "AIQDataStore.h"
#import "AIQDirectCall.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQLaunchableStore.h"
#import "AIQLaunchableSynchronizer.h"
#import "AIQLocalStorage.h"
#import "AIQLog.h"
#import "AIQMessaging.h"
#import "AIQMessagingSynchronizer.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "NSString+Helpers.h"

NSInteger const AIQSessionCredentialsError = 3001;
NSInteger const AIQSessionBackendUnavailableError = 3002;

NSTimeInterval const AIQSessionDefaultTimeoutInterval = 60.0f;

NSString *const AIQSessionStatusCodeKey = @"AIQSessionStatusCode";

NSString *const kAIQOrganizationName = @"organization";
NSString *const kAIQUser = @"user";
NSString *const kAIQStatusCode = @"kAIQStatusCode";
NSString *const kAIQUserId = @"_id";
NSString *const kAIQUserName = @"username";
NSString *const kAIQUserFullName = @"fullName";
NSString *const kAIQUserProfile = @"profile";
NSString *const kAIQUserEmail = @"email";
NSString *const kAIQUserRoles = @"roles";
NSString *const kAIQUserGroups = @"groups";
NSString *const kAIQUserPermissions = @"permissions";

static AIQSession *currentSession = nil;

@interface AIQContext ()

- (instancetype)initForSession:(AIQSession *)session error:(NSError **)error;

@end

@interface AIQDataStore ()

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution error:(NSError **)error;

@end

@interface AIQDirectCall ()

- (instancetype)initWithEndpoint:(NSString *)endpoint solution:(NSString *)solution forSession:(id)session error:(NSError **)error;

@end

@interface AIQLaunchableStore ()

- (instancetype)initForSession:(AIQSession *)session error:(NSError **)error;

@end

@interface AIQLocalStorage ()

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution error:(NSError **)error;

@end

@interface AIQMessaging ()

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution error:(NSError **)error;

@end

@interface AIQSynchronization ()

- (instancetype)initForSession:(AIQSession *)session;
- (void)registerSynchronizer:(id<AIQSynchronizer>)synchronizer forType:(NSString *)type;

@end

@interface AIQSession () <NSURLConnectionDataDelegate> {
    NSURLConnection *_connection;
    NSMutableData *_data;
    NSInteger _statusCode;
    NSString *_authorizationString;
    NSString *_sessionKey;
    NSMutableDictionary *_session;
    AIQContext *_context;
    AIQLaunchableStore *_launchableStore;
    AIQSynchronization *_synchronization;
    BOOL _registeredForPushNotifications;
    BOOL _pushNotificationsFailed;
    BOOL _sessionOpened;
    NSString *_basePath;
    NSString *_dbPath;
    NSString *_organizationName;
}

@end

@implementation AIQSession

+ (void)load {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
    if (! root[@"deviceId"]) {
        NSMutableDictionary *mutable = root ? [root mutableCopy] : [NSMutableDictionary dictionary];
        mutable[@"deviceId"] = [[NSUUID UUID] UUIDString];
        [defaults setValue:mutable forKey:@"AIQCoreLib"];
        [defaults synchronize];
    }
}

+ (AIQSession *)currentSession {
    return currentSession;
}

+ (BOOL)canResume {
    @synchronized([AIQSession class]) {
        if (currentSession) {
            return NO;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
        NSString *sessionKey = root[@"currentSession"];
        return (sessionKey != nil);
    }
}

+ (AIQSession *)resume:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    @synchronized([AIQSession class]) {
        if (currentSession != nil) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session already open"];
            }
            return nil;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
        NSString *sessionKey = root[@"currentSession"];
        if (! sessionKey) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session not found"];
            }
            return nil;
        }
        
        AIQLogCInfo(1, @"Resuming session for key %@", sessionKey);
        
        AIQSession *result = [AIQSession new];
        [result setValue:sessionKey forKey:@"sessionKey"];
        [result setValue:[root[@"sessions"][sessionKey] mutableCopy] forKey:@"session"];
        [result setValue:@YES forKey:@"sessionOpened"];
        
        if (! [result prepare:error]) {
            return nil;
        }
        AIQLaunchableStore *launchableStore = [[AIQLaunchableStore alloc] initForSession:result error:error];
        if (! launchableStore) {
            return nil;
        }
        [result setValue:launchableStore forKey:@"launchableStore"];
        
        AIQContext *context = [[AIQContext alloc] initForSession:result error:error];
        if (! context) {
            return nil;
        }
        [result setValue:context forKey:@"context"];
        
        currentSession = result;
        
        return result;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _timeoutInterval = AIQSessionDefaultTimeoutInterval;
    }
    return self;
}

- (BOOL)openForUser:(NSString *)username
       withPassword:(NSString *)password
     inOrganization:(NSString *)organization
            baseURL:(NSURL *)baseURL
              error:(NSError **)error {
    return [self openForUser:username
                withPassword:password
                 andUserInfo:nil
              inOrganization:organization
                     baseURL:baseURL
                       error:error];
}

- (BOOL)openForUser:(NSString *)username
       withPassword:(NSString *)password
        andUserInfo:(NSDictionary *)userInfo
     inOrganization:(NSString *)organization
            baseURL:(NSURL *)baseURL
              error:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        if (_session) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Session already open"];
            }
            return NO;
        }
        
        if (_connection) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Opening in progress"];
            }
            return NO;
        }
        
        if (! username) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Username not specified"];
            }
            return NO;
        }
        
        if (! password) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Password not specified"];
            }
            return NO;
        }
        
        if (! organization) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Organization not specified"];
            }
            return NO;
        }
        
        if (! baseURL) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Base URL not specified"];
            }
            return NO;
        }
        
        AIQLogCInfo(1, @"Will log in to %@ as %@", baseURL.absoluteString, username);
        
        NSMutableDictionary *device = [NSMutableDictionary dictionary];
        device[@"clientLibVersion"] = [AIQCoreLibInternal clientLibVersion];
#if TARGET_OS_IPHONE
        NSString *clientVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
        if (clientVersion) {
            device[@"clientVersion"] = clientVersion;
        }
        device[@"os"] = @"iOS";
        device[@"osVersion"] = [UIDevice currentDevice].systemVersion;
        
        Class jsBridgeClass = NSClassFromString(@"AIQJSBridgeInternal");
        if (jsBridgeClass) {
            SEL selector = NSSelectorFromString(@"apiLevel");
            NSMethodSignature *signature = [jsBridgeClass methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [invocation setTarget:jsBridgeClass];
            [invocation invoke];
            NSUInteger jsApiLevel;
            [invocation getReturnValue:&jsApiLevel];
            device[@"jsApiLevel"] = @(jsApiLevel);
        }
#else
        device[@"os"] = @"Mac";
        device[@"osVersion"] = [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
        NSDictionary *context = [NSDictionary dictionaryWithObject:device forKey:@"com.appearnetworks.aiq.device"];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
        
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:4 + (userInfo ? userInfo.count : 0)];
        [array addObject:@"grant_type=password"];
        [array addObject:[NSString stringWithFormat:@"username=%@", [username URLEncode]]];
        [array addObject:[NSString stringWithFormat:@"password=%@", [password URLEncode]]];
        [array addObject:[NSString stringWithFormat:@"x-deviceId=%@", root[@"deviceId"]]];
        [array addObject:[NSString stringWithFormat:@"x-context=%@", [context JSONString]]];
        if (userInfo) {
            for (NSString *key in userInfo) {
                if ((! [key isEqualToString:@"username"]) &&
                    (! [key isEqualToString:@"password"]) &&
                    (! [key isEqualToString:@"deviceId"]) &&
                    (! [key isEqualToString:@"context"])) {
                    NSString *normalizedKey = ([key hasPrefix:@"x-"] ? key : [NSString stringWithFormat:@"x-%@", key]);
                    [array addObject:[normalizedKey stringByAppendingFormat:@"=%@", userInfo[key]]];
                }
            }
        }
        _authorizationString = [array componentsJoinedByString:@"&"];
        _organizationName = organization;
        
        NSString *string = [baseURL absoluteString];
        NSURL *url;
        if ([string hasSuffix:@"/"]) {
            url = [NSURL URLWithString:[string stringByAppendingFormat:@"?orgName=%@", organization]];
        } else {
            url = [NSURL URLWithString:[string stringByAppendingFormat:@"/?orgName=%@", organization]];
        }
        
        _sessionKey = [[NSString stringWithFormat:@"%@:%@:%@", string, organization, username] lowercaseString];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:_timeoutInterval];
        request.HTTPMethod = @"GET";
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_connection start];
        
        return YES;
    }
}

- (BOOL)isOpening {
    @synchronized(self) {
        return (_connection != nil);
    }
}

- (BOOL)isOpen {
    @synchronized(self) {
        if ((! _session) || (! _sessionKey)) {
            return NO;
        }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
        if (! root) {
            return NO;
        }
        return [_sessionKey isEqualToString:root[@"currentSession"]];
    }
}

- (BOOL)close:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    @synchronized(self) {
        if (! _session) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Session already closed"];
            }
            return NO;
        }
        
        AIQLogCInfo(1, @"Closing session");
        
        if (_synchronization) {
            if ([_synchronization isRunning]) {
                if (! [_synchronization cancel:error]) {
                    return NO;
                }
            }
            [_synchronization close];
            _synchronization = nil;
        }
        
        if (_context) {
            _context = nil;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *root = [[defaults dictionaryForKey:@"AIQCoreLib"] mutableCopy];
        [root removeObjectForKey:@"currentSession"];
        [defaults setObject:root forKey:@"AIQCoreLib"];
        [defaults synchronize];
        
        NSDictionary *body = @{@"deviceId": root[@"deviceId"]};
        NSString *logout = _session[@"logout"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:logout]
                                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                           timeoutInterval:_timeoutInterval];
        request.HTTPMethod = @"POST";
        request.HTTPBody = [[body JSONString] dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"BEARER %@", _session[@"accessToken"]] forHTTPHeaderField:@"Authorization"];
        [NSURLConnection connectionWithRequest:request delegate:nil];
        
        _sessionKey = nil;
        _session = nil;
        
        currentSession = nil;
        _sessionOpened = NO;
        
        if (_delegate) {
            [_delegate sessionDidClose:self];
        }
        
        return YES;
    }
}

- (BOOL)cancel:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    @synchronized(self) {
        if (! _connection) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Not connecting"];
            }
            return NO;
        }
        
        AIQLogCInfo(1, @"Cancelling session operation");
        [_connection cancel];
        _connection = nil;
        _sessionKey = nil;
        _session = nil;
        return YES;
    }
}

- (NSString *)sessionId {
    return _sessionKey;
}

- (id)propertyForName:(NSString *)name {
    if (! _session) {
        return nil;
    }
    
    if (! name) {
        return nil;
    }
    
    id value = [_session valueForKey:name];
    return value ? [value copy] : nil;
}

- (void)setProperty:(id)property forName:(NSString *)name {
    if (! _session) {
        return;
    }
    
    if (! name) {
        return;
    }
    
    _session[name] = property;
    [self synchronizeProperties];
}

- (BOOL)hasRole:(NSString *)role {
    if (! role) {
        return NO;
    }
    
    return [_session[kAIQUser][kAIQUserRoles] containsObject:role];
}

- (BOOL)hasPermission:(NSString *)permission {
    if (! permission) {
        return NO;
    }
    
    return [_session[kAIQUser][kAIQUserPermissions] containsObject:permission];
}

- (BOOL)solutions:(void (^)(NSString *, NSError *__autoreleasing *))processor error:(NSError *__autoreleasing *)error {
    FMDatabase *db = [FMDatabase databaseWithPath:_dbPath];
    if (! [db open]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    FMResultSet *rs = [db executeQuery:@"SELECT DISTINCT solution FROM documents ORDER BY solution ASC"];
    if (! rs) {
        [db close];
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    NSError *localError = nil;
    while ([rs next]) {
        NSString *solution = [rs stringForColumnIndex:0];
        processor(solution, &localError);
        if (localError) {
            [rs close];
            [db close];
            if (error) {
                *error = localError;
            }
            return NO;
        }
    }
    [rs close];
    [db close];
    
    return YES;
}

- (AIQContext *)context:(NSError *__autoreleasing *)error {
    return _context;
}

- (AIQDataStore *)dataStoreForSolution:(NSString *)solution error:(NSError *__autoreleasing *)error {
    return [[AIQDataStore alloc] initForSession:self solution:solution error:error];
}

- (AIQLaunchableStore *)launchableStore:(NSError *__autoreleasing *)error {
    return _launchableStore;
}

- (AIQLocalStorage *)localStorageForSolution:(NSString *)solution error:(NSError *__autoreleasing *)error {
    return [[AIQLocalStorage alloc] initForSession:self solution:solution error:error];
}

- (AIQDirectCall *)directCallForSolution:(NSString *)solution endpoint:(NSString *)endpoint error:(NSError *__autoreleasing *)error {
    return [[AIQDirectCall alloc] initWithEndpoint:endpoint solution:solution forSession:self error:error];
}

- (AIQMessaging *)messagingForSolution:(NSString *)solution error:(NSError *__autoreleasing *)error {
    return [[AIQMessaging alloc] initForSession:self solution:solution error:error];
}

- (AIQSynchronization *)synchronization:(NSError **)error {
    return _synchronization;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<AIQSession: %p (%@)>", self, _sessionKey];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Connection failed: %@", error.localizedDescription);
    [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _connection = nil;
    _session = nil;
    _sessionKey = nil;
    
    if (_delegate) {
        [_delegate session:self openDidFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault userInfo:error.userInfo]];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    _statusCode = httpResponse.statusCode;
    
    if (httpResponse.expectedContentLength == -1) {
        _data = [NSMutableData data];
    } else {
        _data = [NSMutableData dataWithCapacity:(NSUInteger)httpResponse.expectedContentLength];
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _connection = nil;
    
    if (_sessionOpened) {
        if ((_statusCode == 201) || (_statusCode == 204)) {
            AIQLogCInfo(1, @"Did register for push notifications");
            _registeredForPushNotifications = YES;
            _data = nil;
            return;
        } else if (_statusCode != 200) {
            NSDictionary *json = [_data JSONObject];
            _data = nil;
            
            if (json) {
                AIQLogCWarn(1, @"Did fail to register for push notifications: %@", json[@"error"]);
            } else {
                AIQLogCWarn(1, @"Did fail to register for push notifications");
            }
            if (_statusCode < 500) {
                _pushNotificationsFailed = YES;
            }
            return;
        }
    }
    
    NSDictionary *json = [_data JSONObject];
    _data = nil;
    
    if ((_statusCode != 200) || (! json)) {
        _connection = nil;
        _session = nil;
        _sessionKey = nil;
        if (_delegate) {
            if ((json) && (json[@"error"])) {
                NSString *message;
                NSInteger code = AIQErrorConnectionFault;
                if ((json) && (json[@"error"])) {
                    NSString *key = json[@"error"];
                    if ([key isEqualToString:@"invalid_grant"]) {
                        code = AIQSessionCredentialsError;
                    } else if ([key isEqualToString:@"not_found"]) {
                        code = AIQErrorIdNotFound;
                    } else if ([key isEqualToString:@"invalid_scope"]) {
                        code = AIQErrorUnauthorized;
                    } else if ([key isEqualToString:@"service_unavailable"]) {
                        code = AIQSessionBackendUnavailableError;
                    }
                    message = json[@"error_description"];
                    if (! message) {
                        message = @"Authentication error";
                    }
                } else {
                    message = @"Error communicating with the backend";
                }
                [_delegate session:self openDidFailWithError:[AIQError errorWithCode:code message:message]];
            } else {
                [_delegate session:self openDidFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault userInfo:@{NSLocalizedDescriptionKey: @"Invalid response from AIQ Server",
                                                                                                                   AIQSessionStatusCodeKey: @(_statusCode)}]];
            }
        }
        return;
    }
    
    if (json[@"user"]) {
        NSString *accessToken = json[@"access_token"];
        NSMutableDictionary *userProfile = [json[@"user"] mutableCopy];
        
        if (! userProfile[kAIQUserFullName]) {
            userProfile[kAIQUserFullName] = @"";
        }
        if (! userProfile[kAIQUserProfile]) {
            userProfile[kAIQUserProfile] = @{};
        }
        if (! userProfile[kAIQUserGroups]) {
            userProfile[kAIQUserGroups] = @[];
        }
        if (! userProfile[kAIQUserRoles]) {
            userProfile[kAIQUserRoles] = @[];
        }
        if (! userProfile[kAIQUserPermissions]) {
            userProfile[kAIQUserPermissions] = @[];
        }
        
        _session[@"accessToken"] = accessToken;
        _session[kAIQUser] = [userProfile copy];
        if (json[@"protocol_version"]) {
            _session[@"protocolVersion"] = json[@"protocol_version"];
        } else {
            _session[@"protocolVersion"] = @0;
        }

        if (json[@"sync_interval"]) {
            _session[@"syncInterval"] = json[@"sync_interval"];
        } else {
            // Remember to unset any old value that might still be present
            [_session removeObjectForKey:@"syncInterval"];
        }
        
        NSString *deviceURL = _session[@"deviceURL"];
        [_session removeObjectForKey:@"deviceURL"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:deviceURL]
                                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                           timeoutInterval:_timeoutInterval];
        request.HTTPMethod = @"GET";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"BEARER %@", accessToken] forHTTPHeaderField:@"Authorization"];
        
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_connection start];
    } else if (json[@"links"]) {
        if (_session) {
            NSDictionary *links = json[@"links"];
            if (links[@"logout"]) {
                _session[@"logout"] = links[@"logout"];
            }
            if (links[@"startdatasync"]) {
                _session[@"startdatasync"] = links[@"startdatasync"];
            }
            if (links[@"direct"]) {
                _session[@"direct"] = links[@"direct"];
            }
            if (links[@"comessage"]) {
                _session[@"comessage"] = links[@"comessage"];
            }
            
            NSError *error = nil;
            if (! [self prepare:&error]) {
                _session = nil;
                _sessionKey = nil;
                if (_delegate) {
                    [_delegate session:self openDidFailWithError:error];
                }
                return;
            }
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
            NSMutableDictionary *newRoot = root ? [root mutableCopy] : [NSMutableDictionary dictionary];
            newRoot[@"currentSession"] = _sessionKey;
            NSDictionary *sessions = newRoot[@"sessions"];
            NSMutableDictionary *newSessions = sessions ? [sessions mutableCopy] : [NSMutableDictionary dictionary];
            newSessions[_sessionKey] = _session;
            newRoot[@"sessions"] = newSessions;
            [defaults setObject:newRoot forKey:@"AIQCoreLib"];
            [defaults synchronize];
            
            _context = [[AIQContext alloc] initForSession:self error:nil];
            
            currentSession = self;
            _sessionOpened = YES;
            
            if (_delegate) {
                [_delegate sessionDidOpen:self];
            }
        } else {
            NSString *deviceURL = json[@"links"][@"device"];
            NSString *tokenURL = json[@"links"][@"token"];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];
            if (root) {
                NSDictionary *sessions = root[@"sessions"];
                if (sessions) {
                    NSDictionary *session = sessions[_sessionKey];
                    if (session) {
                        _session = [session mutableCopy];
                    } else {
                        _session = [NSMutableDictionary dictionary];
                    }
                } else {
                    _session = [NSMutableDictionary dictionary];
                }
            } else {
                _session = [NSMutableDictionary dictionary];
            }
            _session[@"deviceURL"] = deviceURL;
            _session[kAIQOrganizationName] = _organizationName;
            _organizationName = nil;
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:tokenURL]
                                                                   cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                               timeoutInterval:_timeoutInterval];
            request.HTTPMethod = @"POST";
            request.HTTPBody = [_authorizationString dataUsingEncoding:NSUTF8StringEncoding];
            _authorizationString = nil;
            [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
            
            _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
            [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [_connection start];
        }
    }
}

#pragma mark - Private API

- (void)synchronizeProperties {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *root = [[defaults dictionaryForKey:@"AIQCoreLib"] mutableCopy];
    NSMutableDictionary *sessions = [root[@"sessions"] mutableCopy];
    sessions[_sessionKey] = _session;
    root[@"sessions"] = sessions;
    [defaults setValue:root forKey:@"AIQCoreLib"];
    [defaults synchronize];
    NSString *deviceToken = [defaults valueForKey:@"AIQDeviceToken"];
    
    if ((_session[@"push"]) && (deviceToken) && (! _pushNotificationsFailed) && (! _registeredForPushNotifications) && (! _connection)) {
        [self registerForPushNotifications:deviceToken];
    }
}

- (void)registerForPushNotifications:(NSString *)deviceToken {
    AIQLogCInfo(1, @"Registering for push notifications");
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_session[@"push"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_timeoutInterval];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [@{@"service": @"apn", @"token": deviceToken} JSONData];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", _session[@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [_connection start];
}

- (BOOL)prepare:(NSError *__autoreleasing *)error {
    if (! [self preparePool:error]) {
        return NO;
    }
    
    if (! [self prepareModules:error]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)prepareModules:(NSError *__autoreleasing *)error {
    _synchronization = [[AIQSynchronization alloc] initForSession:self];
    [_synchronization registerSynchronizer:[[AIQLaunchableSynchronizer alloc] initForSession:self] forType:@"_launchable"];
    [_synchronization registerSynchronizer:[[AIQMessagingSynchronizer alloc] initForSession:self] forType:@"_backendmessage"];
    [_synchronization registerSynchronizer:[[AIQContextSynchronizer alloc] initForSession:self] forType:@"_backendcontext"];
    
    return YES;
}

- (BOOL)setWriteAheadLocking:(NSError *__autoreleasing *)error {
    FMDatabase *database = [FMDatabase databaseWithPath:_dbPath];
    if (! [database open]) {
        if (error) {
            *error = [database lastError];
        }
        return NO;
    }
    
    FMResultSet *rs = [database executeQuery:@"PRAGMA journal_mode=WAL"];
    if (! rs) {
        if (error) {
            *error = [database lastError];
        }
        [database close];
        return NO;
    }
    
    BOOL result = YES;
    if ([rs next]) {
        if (! [[rs stringForColumnIndex:0] isEqualToString:@"wal"]) {
            result = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Could not set write ahead locking"];
            }
        }
    } else {
        result = NO;
        if (error) {
            *error = [database lastError];
        }
    }
    
    [rs close];
    [database close];
    
    return result;
}

- (BOOL)preparePool:(NSError *__autoreleasing *)error {
    _basePath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    _basePath = [_basePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%02lX", (long)_sessionKey.hash]];
    
    if (! [self handleDataVersioning:error]) {
        return NO;
    }
    
    _dbPath = [_basePath stringByAppendingPathComponent:@"data.sqlite3"];
    
    if (! [self setWriteAheadLocking:error]) {
        return NO;
    }
    
    FMDBMigrationManager *manager = [FMDBMigrationManager managerWithDatabaseAtPath:_dbPath migrationsBundle:[NSBundle bundleForClass:[AIQSession class]]];
    if (! [manager hasMigrationsTable]) {
        AIQLogCInfo(1, @"Creating migration database");
        if (! [manager createMigrationsTable:error]) {
            return NO;
        }
    }
    
    if ([manager needsMigration]) {
        AIQLogCInfo(1, @"Migrating the database");
        if (! [manager migrateDatabaseToVersion:INT64_MAX progress:nil error:error]) {
            return NO;
        }
    }
    
    _launchableStore = [[AIQLaunchableStore alloc] initForSession:self error:error];
    if (! _launchableStore) {
        return NO;
    }
    
    if (! [self handleLaunchableMigration:error]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)handleDataVersioning:(NSError *__autoreleasing *)error {
    NSString *hash = [NSString stringWithFormat:@"%02lX", (long)_sessionKey.hash];
    NSString *oldPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:hash];
    NSString *newBasePath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *newPath = [newBasePath stringByAppendingPathComponent:hash];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *localError = nil;
    
    if (! [fileManager fileExistsAtPath:newPath]) {
        if ([fileManager fileExistsAtPath:oldPath]) {
            AIQLogCInfo(1, @"Migrating folder structure from %@ to %@", oldPath, newPath);
            if (! [fileManager createDirectoryAtPath:newBasePath withIntermediateDirectories:YES attributes:@{NSFileProtectionKey: NSFileProtectionComplete} error:&localError]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                return NO;
            }
            if (! [fileManager moveItemAtPath:oldPath toPath:newPath error:&localError]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                return NO;
            }
            AIQLogCInfo(1, @"Did migrate folder structure");
        } else {
            if (! [fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:@{NSFileProtectionKey: NSFileProtectionComplete} error:&localError]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                return NO;
            }
        }
    }
    
    oldPath = [newPath stringByAppendingPathComponent:@"DataSync.sqlite3"];
    if ([fileManager fileExistsAtPath:oldPath]) {
        for (NSString *file in [fileManager contentsOfDirectoryAtPath:newPath error:nil]) {
            if (! [fileManager removeItemAtPath:[newPath stringByAppendingPathComponent:file] error:&localError]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                return NO;
            }
        }
        [_session removeObjectForKey:@"download"];
    }
    
    return YES;
}

- (BOOL)handleLaunchableMigration:(NSError *__autoreleasing *)error {
    Class jsBridgeClass = NSClassFromString(@"AIQJSBridgeInternal");
    if (jsBridgeClass) {
        SEL selector = NSSelectorFromString(@"cordovaVersion");
        NSMethodSignature *signature = [jsBridgeClass methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:selector];
        [invocation setTarget:jsBridgeClass];
        [invocation invoke];
        void *tmp;
        [invocation getReturnValue:&tmp];
        NSString *currentCordovaVersion = (__bridge NSString *)tmp;
        
        selector = NSSelectorFromString(@"apiLevel");
        signature = [jsBridgeClass methodSignatureForSelector:selector];
        invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:selector];
        [invocation setTarget:jsBridgeClass];
        [invocation invoke];
        NSUInteger currentApiLevel;
        [invocation getReturnValue:&currentApiLevel];
        
        AIQLogCInfo(1, @"Current Cordova version is %@", currentCordovaVersion);
        
        NSString *oldCordovaVersion = _session[@"cordovaVersion"];
        if ( oldCordovaVersion) {
            AIQLogCInfo(1, @"Old Cordova version is %@", oldCordovaVersion);
        } else {
            AIQLogCInfo(1, @"No Cordova version property available");
            oldCordovaVersion = @"0.0.0";
        }
        
        AIQLogCInfo(1, @"Current API level is %lu", (unsigned long)currentApiLevel);
        
        NSUInteger oldApiLevel;
        if (_session[@"apiLevel"]) {
            oldApiLevel = [_session[@"apiLevel"] integerValue];
            AIQLogCInfo(1, @"Old API level is %lu", (unsigned long)oldApiLevel);
        } else {
            AIQLogCInfo(1, @"No API level property available");
            oldApiLevel = 0;
        }
        
        if ((oldApiLevel < currentApiLevel) ||
            ([oldCordovaVersion compare:currentCordovaVersion options:NSNumericSearch] == NSOrderedAscending)) {
            AIQLogCInfo(1, @"Reloading launchables");
            // time to migrate
            _session[@"cordovaVersion"] = currentCordovaVersion;
            _session[@"apiLevel"] = @(currentApiLevel);
            if (! [_launchableStore reload:error]) {
                return NO;
            }
        } else {
            AIQLogCInfo(1, @"API levels are up to date");
        }
    }
    
    return YES;
}

@end
