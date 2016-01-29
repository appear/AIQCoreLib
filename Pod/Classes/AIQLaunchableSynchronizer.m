#import <FMDB/FMDB.h>

#import "AIQJSON.h"
#import "AIQLaunchableStore.h"
#import "AIQLaunchableSynchronizer.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "ZipArchive.h"
#import "common.h"

@interface AIQLaunchableSynchronizer () {
    FMDatabasePool *_pool;
    NSString *_basePath;
}

@end

@implementation AIQLaunchableSynchronizer

- (instancetype)initForSession:(AIQSession *)session {
    self = [super init];
    if (self) {
        _basePath = [session valueForKey:@"basePath"];
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
    }
    return self;
}

- (void)didCreateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? and identifier = ?", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Failed to retrieve content for launchable %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            AIQLogCError(1, @"Document does not exist for launchable %@", identifier);
            return;
        }
        
        NSDictionary *document = [[rs dataForColumnIndex:0] JSONObject];
        [rs close];
        
        NSString *name = document[@"name"];
        if (! name) {
            name = @"";
        }
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[AIQDocumentIdUserInfoKey] = identifier;
        info[AIQSolutionUserInfoKey] = solution;
        info[AIQLaunchableNameUserInfoKey] = name;
        NOTIFY(AIQDidInstallLaunchableNotification, self, info);
    }];
}

- (void)didUpdateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? and identifier = ?", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Failed to retrieve content for launchable %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            AIQLogCError(1, @"Document does not exist for launchable %@", identifier);
            return;
        }
        
        NSDictionary *document = [[rs dataForColumnIndex:0] JSONObject];
        [rs close];
        
        rs = [db executeQuery:@"SELECT state FROM attachments WHERE solution = ? AND identifier = ? AND name = 'icon'", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Failed to retrieve attachment information for launchable %@: %@", identifier, [db lastError].localizedDescription);
            NOTIFY(AIQLaunchableDidFailNotification, self, @{AIQDocumentIdUserInfoKey: identifier});
            return;
        }
        
        AIQAttachmentState state = [rs next] ? [rs intForColumnIndex:0] : AIQAttachmentStateUnavailable;
        [rs close];
        
        NSString *name = document[@"name"];
        if (! name) {
            name = @"";
        }
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[AIQDocumentIdUserInfoKey] = identifier;
        info[AIQSolutionUserInfoKey] = solution;
        info[AIQLaunchableNameUserInfoKey] = name;
        if (state == AIQAttachmentStateAvailable) {
            NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"icon"];
            info[AIQLaunchableIconPathUserInfoKey] = path;
        }
        NOTIFY(AIQDidUpdateLaunchableNotification, self, info);
    }];
}

- (void)didDeleteDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidUninstallLaunchableNotification, self, (@{AIQDocumentIdUserInfoKey:identifier, AIQSolutionUserInfoKey: solution}));
    
    NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"content.webapp"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        if (! [fileManager removeItemAtPath:path error:&error]) {
            AIQLogCError(1, @"Failed to remove data for launchable %@: %@", identifier, error.localizedDescription);
        }
    }
}

- (void)didSynchronizeDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)didRejectDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    
}

- (void)documentError:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status {
    
}

- (void)didCreateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if ([name isEqualToString:@"content"]) {
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Failed to retrieve content for launchable %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Document does not exist for launchable %@", identifier);
                return;
            }
            
            NSDictionary *document = [[rs dataForColumnIndex:0] JSONObject];
            [rs close];
            NSString *name = document[@"name"];
            if (! name) {
                name = @"";
            }
            NOTIFY(AIQDidInstallLaunchableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                 AIQSolutionUserInfoKey: solution,
                                                                 AIQLaunchableNameUserInfoKey: name}));
        }];
    }
}

- (void)didUpdateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)didDeleteAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)didSynchronizeAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)didRejectAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    
}

- (void)attachmentError:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status {
    
}

- (void)willDownloadAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if ([name isEqualToString:@"content"]) {
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Failed to retrieve content for launchable %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Document does not exist for launchable %@", identifier);
                return;
            }
            
            NSDictionary *document = [[rs dataForColumnIndex:0] JSONObject];
            [rs close];
            NSString *name = document[@"name"];
            if (! name) {
                name = @"";
            }
            NOTIFY(AIQWillDownloadLaunchableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                   AIQSolutionUserInfoKey: solution,
                                                                   AIQLaunchableNameUserInfoKey: name}));
        }];
    }
}

- (void)attachmentDidBecomeAvailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if ([name isEqualToString:@"content"]) {
        NSString *folder = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
        NSString *path = [folder stringByAppendingPathComponent:@"content"];
        __block NSDictionary *document = nil;
        __block AIQAttachmentState state = AIQAttachmentStateUnavailable;
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? and identifier = ?", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Failed to retrieve content for launchable %@: %@", identifier, [db lastError].localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, @{AIQDocumentIdUserInfoKey: identifier});
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Document does not exist for launchable %@", identifier);
                return;
            }
            
            document = [[rs dataForColumnIndex:0] JSONObject];
            [rs close];
            
            rs = [db executeQuery:@"SELECT state FROM attachments WHERE solution = ? AND identifier = ? AND name = 'icon'", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Failed to retrieve attachment information for launchable %@: %@", identifier, [db lastError].localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, @{AIQDocumentIdUserInfoKey: identifier});
                return;
            }
            
            if ([rs next]) {
                state = [rs intForColumnIndex:0];
            }
            [rs close];
        }];
        
        if (! document) {
            return;
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *appPath = [path stringByAppendingPathExtension:@"webapp"];
        NSString *tmpPath = [path stringByAppendingPathExtension:@"unzipped"];
        NSError *error = nil;
        
        if ([fileManager fileExistsAtPath:tmpPath]) {
            AIQLogCInfo(1, @"Temporary folder for application %@ exists, cleaning up", identifier);
            if (! [fileManager removeItemAtPath:tmpPath error:&error]) {
                AIQLogCError(1, @"Failed to clean up launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
        }
        
        ZipArchive *zip = [ZipArchive new];
        
        if (! [zip UnzipOpenFile:path]) {
            AIQLogCError(1, @"Could not open zip file for application %@", identifier);
            NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
            return;
        }
        
        if (! [zip UnzipFileTo:tmpPath overWrite:YES]) {
            AIQLogCError(4, @"Could not extract application %@", identifier);
            NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
            return;
        }
        
        if ([[document valueForKeyPath:@"config.mock"] boolValue]) {
            AIQLogCInfo(1, @"Application %@ is in mock mode, skipping core API", identifier);
        } else {
            AIQLogCInfo(1, @"Copying core API into application %@", identifier);
            NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"AIQJSBridge" ofType:@"bundle"];
            if (! [self copyFile:@"cordova.js" from:bundlePath to:tmpPath using:fileManager error:&error]) {
                AIQLogCError(1, @"Failed to copy bridge files to launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
            if (! [self copyFile:@"cordova_plugins.js" from:bundlePath to:tmpPath using:fileManager error:&error]) {
                AIQLogCError(1, @"Failed to copy bridge files to launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
            if (! [self copyFile:@"plugins" from:bundlePath to:tmpPath using:fileManager error:&error]) {
                AIQLogCError(1, @"Failed to copy bridge files to launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
            if (! [self copyFile:@"cordova.js"
                            from:bundlePath
                          toFile:@"aiq-api.js"
                              in:[tmpPath stringByAppendingPathComponent:@"aiq"]
                           using:fileManager
                           error:&error]) {
                AIQLogCError(1, @"Failed to copy bridge files to launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
        }
        
        if ([fileManager fileExistsAtPath:appPath isDirectory:nil]) {
            if (! [fileManager removeItemAtPath:appPath error:&error]) {
                AIQLogCError(1, @"Failed to remove old data for launchable %@: %@", identifier, error.localizedDescription);
                NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
                return;
            }
        }
        
        if (! [fileManager moveItemAtPath:tmpPath toPath:appPath error:&error]) {
            AIQLogCError(1, @"Failed to move data for launchable %@: %@", identifier, error.localizedDescription);
            NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
            return;
        }
        
        NSString *canaryPath = [appPath stringByAppendingPathComponent:@".aiq_canary"];
        [fileManager createFileAtPath:canaryPath contents:[NSData data] attributes:@{NSFileProtectionKey: NSFileProtectionComplete}];
        
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[AIQDocumentIdUserInfoKey] = identifier;
        info[AIQSolutionUserInfoKey] = solution;
        info[AIQLaunchablePathUserInfoKey] = appPath;
        if (state == AIQAttachmentStateAvailable) {
            NSString *path = [folder stringByAppendingPathComponent:@"icon"];
            info[AIQLaunchableIconPathUserInfoKey] = path;
        }
        
        NOTIFY(AIQDidDownloadLaunchableNotification, self, info);
    } else if ([name isEqualToString:@"icon"]) {
        NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"icon"];
        NOTIFY(AIQLaunchableIconDidChangeNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                AIQSolutionUserInfoKey: solution,
                                                                AIQLaunchableIconPathUserInfoKey: path}));
    }
}

- (void)close {
    _pool = nil;
}

- (void)attachmentDidBecomeUnavailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if ([name isEqualToString:@"content"]) {
        NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
    }
}

- (void)attachmentDidFail:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if ([name isEqualToString:@"content"]) {
        NOTIFY(AIQLaunchableDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution}));
    }
}

- (void)attachmentDidProgress:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution progress:(float)progress {
    if ([name isEqualToString:@"content"]) {
        NOTIFY(AIQLaunchableDidProgressNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQSolutionUserInfoKey: solution, AIQAttachmentProgressUserInfoKey: @(progress)}));
    }
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
