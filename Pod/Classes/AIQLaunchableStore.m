#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQLaunchableStore.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "common.h"
#import "ZipArchive.h"

NSString *const AIQDidInstallLaunchableNotification = @"AIQDidInstallLaunchableNotification";
NSString *const AIQDidUninstallLaunchableNotification = @"AIQDidUninstallLaunchableNotification";
NSString *const AIQDidUpdateLaunchableNotification = @"AIQDidUpdateLaunchableNotification";

NSString *const AIQWillDownloadLaunchableNotification = @"AIQWillDownloadLaunchableNotification";
NSString *const AIQLaunchableDidProgressNotification = @"AIQLaunchableDidProgressNotification";
NSString *const AIQDidDownloadLaunchableNotification = @"AIQDidDownloadLaunchableNotification";
NSString *const AIQLaunchableDidFailNotification = @"AIQLaunchableDidFailNotification";

NSString *const AIQLaunchableIconDidChangeNotification = @"AIQLaunchableIconDidChangeNotification";

NSString *const kAIQLaunchableSolution = @"kAIQLaunchableSolution";
NSString *const kAIQLaunchableName = @"kAIQLaunchableName";
NSString *const kAIQLaunchablePath = @"kAIQLaunchablePath";
NSString *const kAIQLaunchableIconPath = @"kAIQLaunchableIconPath";
NSString *const kAIQLaunchableAvailable = @"kAIQLaunchableAvailable";
NSString *const kAIQLaunchableNotification = @"kAIQLaunchableNotification";

NSString *const AIQLaunchableNameUserInfoKey = @"AIQLaunchableNameUserInfoKey";
NSString *const AIQLaunchablePathUserInfoKey = @"AIQLaunchablePathUserInfoKey";
NSString *const AIQLaunchableIconPathUserInfoKey = @"AIQLaunchableIconPathUserInfoKey";

@implementation AIQLaunchableStore {
    FMDatabaseQueue *_queue;
    NSString *_basePath;
}

- (instancetype)initForSession:(AIQSession *)session error:(NSError *__autoreleasing *)error {
    self = [super init];
    if (self) {
        _basePath = [session valueForKey:@"basePath"];
        _queue = [FMDatabaseQueue databaseQueueWithPath:[session valueForKey:@"dbPath"]];
    }
    return self;
}

- (BOOL)reload:(NSError *__autoreleasing *)error {
    __block BOOL success = YES;
    
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT a.solution, a.identifier, a.name, d.data FROM attachments a, documents d "
                           "WHERE a.solution = d.solution AND a.identifier = d.identifier AND a.name = 'content' AND a.state = ?",
                           @(AIQAttachmentStateAvailable)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            success = NO;
            return;
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *localError = nil;
        while ([rs next]) {
            NSString *solution = [rs stringForColumnIndex:0];
            NSString *identifier = [rs stringForColumnIndex:1];
            NSString *name = [rs stringForColumnIndex:2];
            NSDictionary *data = [[rs dataForColumnIndex:3] JSONObject];
            
            NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
            NSString *appPath = [path stringByAppendingPathExtension:@"webapp"];
            NSString *tmpPath = [path stringByAppendingPathExtension:@"unzipped"];
            
            if ([fileManager fileExistsAtPath:tmpPath]) {
                if (! [fileManager removeItemAtPath:tmpPath error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    return;
                }
            }
            
            ZipArchive *zip = [ZipArchive new];
            if (! [zip UnzipOpenFile:path]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Could not open zip file"];
                }
                success = NO;
                return;
            }
            
            if (! [zip UnzipFileTo:tmpPath overWrite:YES]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Could not extract zip file"];
                }
                success = NO;
                return;
            }
            
            if (! [[data valueForKeyPath:@"config.mock"] boolValue]) {
                NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"AIQJSBridge" ofType:@"bundle"];
                if (! [self copyFile:@"cordova.js" from:bundlePath to:tmpPath using:fileManager error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    break;
                }
                if (! [self copyFile:@"cordova_plugins.js" from:bundlePath to:tmpPath using:fileManager error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    break;
                }
                if (! [self copyFile:@"plugins" from:bundlePath to:tmpPath using:fileManager error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    break;
                }
                if (! [self copyFile:@"cordova.js"
                                from:bundlePath
                              toFile:@"aiq-api.js"
                                  in:[tmpPath stringByAppendingPathComponent:@"aiq"]
                               using:fileManager
                               error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    break;
                }
            }
            
            if ([fileManager fileExistsAtPath:appPath isDirectory:nil]) {
                if (! [fileManager removeItemAtPath:appPath error:&localError]) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                    }
                    success = NO;
                    break;
                }
            }
            
            if (! [fileManager moveItemAtPath:tmpPath toPath:appPath error:&localError]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                [rs close];
                success = NO;
                break;
            }
        }
        
        [rs close];
    }];
    
    return success;
}

- (BOOL)processLaunchables:(void (^)(NSDictionary *, NSError *__autoreleasing *))processor error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! processor) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"];
        }
        return NO;
    }
    __block BOOL result = NO;
    
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT d.identifier, d.solution, d.data, a.state FROM documents d, attachments a "
                                            "WHERE a.identifier = d.identifier "
                                            "AND d.status != ? "
                                            "AND d.type = '_launchable' "
                                            "AND a.name = 'content' "
                                            "AND a.status != ? "
                                            "AND a.state != ?",
                                            @(AIQSynchronizationStatusDeleted),
                                            @(AIQSynchronizationStatusDeleted),
                                            @(AIQAttachmentStateFailed)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        while ([rs next]) {
            NSString *identifier = [rs stringForColumnIndex:0];
            NSString *solution = [rs stringForColumnIndex:1];
            NSString *folder = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
            NSString *launchablePath = [folder stringByAppendingPathComponent:@"content.webapp"];
            if (! [[NSFileManager defaultManager] fileExistsAtPath:launchablePath]) {
                continue;
            }
            
            NSMutableDictionary *mutable = [NSMutableDictionary dictionary];
            NSDictionary *document = [[rs dataForColumnIndex:2] JSONObject];
            NSString *iconPath = [folder stringByAppendingPathComponent:@"icon"];
            mutable[kAIQDocumentId] = identifier;
            mutable[kAIQLaunchableSolution] = solution;
            if (document[@"name"]) {
                mutable[kAIQLaunchableName] = document[@"name"];
            }
            mutable[kAIQLaunchablePath] = launchablePath;
            if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath isDirectory:nil]) {
                mutable[kAIQLaunchableIconPath] = iconPath;
            }
            mutable[kAIQLaunchableAvailable] = @([rs intForColumnIndex:3] == AIQAttachmentStateAvailable);
            
            NSError *localError = nil;
            processor(mutable, &localError);
            if (localError) {
                [rs close];
                if (error) {
                    *error = localError;
                }
                return;
            }
        }
        
        [rs close];
        
        result = YES;
    }];
    
    return result;
}

- (NSDictionary *)launchableWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT d.solution, d.data, a.state FROM documents d, attachments a "
                                            "WHERE a.identifier = d.identifier "
                                            "AND d.identifier = ? "
                                            "AND d.status != ? "
                                            "AND d.type = '_launchable' "
                                            "AND a.name = 'content' "
                                            "AND a.status != ? AND a.state != ?",
                                            identifier,
                                            @(AIQSynchronizationStatusDeleted),
                                            @(AIQSynchronizationStatusDeleted),
                                            @(AIQAttachmentStateFailed)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Launchable not found"];
            }
            return;
        }
        
        NSString *solution = [rs stringForColumnIndex:0];
        NSString *folder = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
        NSDictionary *document = [[rs dataForColumnIndex:1] JSONObject];
        NSString *iconPath = [folder stringByAppendingPathComponent:@"icon"];
        NSMutableDictionary *mutable = [NSMutableDictionary dictionary];
        mutable[kAIQDocumentId] = identifier;
        mutable[kAIQLaunchableSolution] = solution;
        mutable[kAIQLaunchableSolution] = solution;
        if (document[@"name"]) {
            mutable[kAIQLaunchableName] = document[@"name"];
        }
        mutable[kAIQLaunchablePath] = [folder stringByAppendingPathComponent:@"content.webapp"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath isDirectory:nil]) {
            mutable[kAIQLaunchableIconPath] = iconPath;
        }
        mutable[kAIQLaunchableAvailable] = [rs objectForColumnIndex:2];
        result = [mutable copy];
        [rs close];
    }];
    
    return result;
}

- (BOOL)copyFile:(NSString *)file
            from:(NSString *)source
              to:(NSString *)target
           using:(NSFileManager *)fileManager
           error:(NSError *__autoreleasing *)error {
    return [self copyFile:file from:source toFile:file in:target using:fileManager error:error];
}

- (BOOL)copyFile:(NSString *)sourceFile
            from:(NSString *)sourceFolder
          toFile:(NSString *)targetFile
              in:(NSString *)targetFolder
           using:(NSFileManager *)fileManager
           error:(NSError *__autoreleasing *)error {
    NSString *source = [sourceFolder stringByAppendingPathComponent:sourceFile];
    NSString *target = [targetFolder stringByAppendingPathComponent:targetFile];
    
    if ([fileManager fileExistsAtPath:targetFolder]) {
        if ([fileManager fileExistsAtPath:target]) {
            if (! [fileManager removeItemAtPath:target error:error]) {
                return NO;
            }
        }
    } else if (! [fileManager createDirectoryAtPath:targetFolder withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    
    return [fileManager copyItemAtPath:source toPath:target error:error];
}

@end
