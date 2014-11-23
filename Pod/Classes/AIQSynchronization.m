#import "AFHTTPRequestOperationManager.h"
#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "SessionProperties.h"
#import "SynchronizationReceiver.h"

NSString *const AIQDidCreateDocumentNotification = @"AIQDidCreateDocumentNotification";
NSString *const AIQDidUpdateDocumentNotification = @"AIQDidUpdateDocumentNotification";
NSString *const AIQDidDeleteDocumentNotification = @"AIQDidDeleteDocumentNotification";

NSString *const AIQDidCreateAttachmentNotification = @"AIQDidCreateAttachmentNotification";
NSString *const AIQDidUpdateAttachmentNotification = @"AIQDidUpdateAttachmentNotification";
NSString *const AIQDidDeleteAttachmentNotification = @"AIQDidDeleteAttachmentNotification";

NSString *const AIQAttachmentDidBecomeAvailableNotification = @"AIQAttachmentDidBecomeAvailableNotification";
NSString *const AIQAttachmentDidBecomeUnavailableNotification = @"AIQAttachmentDidBecomeUnavailableNotification";
NSString *const AIQAttachmentDidBecomeFailedNotification = @"AIQAttachmentDidBecomeFailedNotification";

NSString *const AIQDocumentIdUserInfoKey = @"AIQDocumentIdUserInfoKey";
NSString *const AIQDocumentTypeUserInfoKey = @"AIQDocumentTypeUserInfoKey";
NSString *const AIQAttachmentNameUserInfoKey = @"AIQAttachmentNameUserInfoKey";

NSString *const AIQSolutionUserInfoKey = @"AIQSolutionUserInfoKey";

@interface AIQSession ()

- (void)storeProperties;

@end

@interface AIQSynchronization () <SynchronizationReceiver> {
    NSString *_basePath;
    NSNotificationCenter *_center;
    FMDatabaseQueue *_queue;
    AFHTTPRequestOperationManager *_manager;
    AIQSession *_session;
    NSMutableDictionary *_synchronizationReceivers;
    BOOL _shouldCancel;
}

@end

@implementation AIQSynchronization

- (void)synchronize:(void (^)(void))success failure:(void (^)(NSError *))failure {
    AIQLogCInfo(1, @"Synchronizing");

    _shouldCancel = NO;
    if (_session[kAIQSessionDownloadUrl]) {
        [self pull:success failure:failure];
    } else {
        [self handshake:success failure:failure];
    }
}

- (void)cancel {
    AIQLogCInfo(1, @"Cancelling");

    [_manager.operationQueue cancelAllOperations];
    _shouldCancel = YES;
}

#pragma mark - SynchronizationReceiver

- (void)didCreateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidCreateDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                              AIQDocumentTypeUserInfoKey: type,
                                                                                              AIQSolutionUserInfoKey: solution}];
    }
}
- (void)didUpdateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidUpdateDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                              AIQDocumentTypeUserInfoKey: type,
                                                                                              AIQSolutionUserInfoKey: solution}];
    }
}
- (void)didDeleteDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidDeleteDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                              AIQDocumentTypeUserInfoKey: type,
                                                                                              AIQSolutionUserInfoKey: solution}];
    }
}

- (void)didCreateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidCreateAttachmentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                AIQDocumentIdUserInfoKey: identifier,
                                                                                                AIQDocumentTypeUserInfoKey: type,
                                                                                                AIQSolutionUserInfoKey: solution}];
    }
}
- (void)didUpdateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidUpdateAttachmentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                AIQDocumentIdUserInfoKey: identifier,
                                                                                                AIQDocumentTypeUserInfoKey: type,
                                                                                                AIQSolutionUserInfoKey: solution}];
    }
}

- (void)didDeleteAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        [_center postNotificationName:AIQDidDeleteAttachmentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                AIQDocumentIdUserInfoKey: identifier,
                                                                                                AIQDocumentTypeUserInfoKey: type,
                                                                                                AIQSolutionUserInfoKey: solution}];
    }
}

- (void)didProgressAttachmentWithName:(NSString *)name
                           downloaded:(unsigned long long)downloadedBytes
                                total:(unsigned long long)totalBytes
                    forDocumentWithId:(NSString *)identifier
                                 type:(NSString *)type
                             solution:(NSString *)solution {
    // do nothing
}

- (void)didChangeState:(AIQAttachmentState)state
  ofAttachmentWithName:(NSString *)name
     forDocumentWithId:(NSString *)identifier
                  type:(NSString *)type
              solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        NSDictionary *userInfo = @{AIQAttachmentNameUserInfoKey: name,
                                   AIQDocumentIdUserInfoKey: identifier,
                                   AIQDocumentTypeUserInfoKey: type,
                                   AIQSolutionUserInfoKey: solution};
        if (state == AIQAttachmentStateAvailable) {
            [_center postNotificationName:AIQAttachmentDidBecomeAvailableNotification object:self userInfo:userInfo];
        } else if (state == AIQAttachmentStateUnavailable) {
            [_center postNotificationName:AIQAttachmentDidBecomeUnavailableNotification object:self userInfo:userInfo];
        } else {
            [_center postNotificationName:AIQAttachmentDidBecomeFailedNotification object:self userInfo:userInfo];
        }
    }
}

#pragma mark - Private API

- (instancetype)init {
    return nil;
}

- (instancetype)initForSession:(AIQSession *)session {
    self = [super init];
    if (self) {
        _basePath = [session valueForKey:@"basePath"];
        _center = [NSNotificationCenter defaultCenter];
        _queue = [FMDatabaseQueue databaseQueueWithPath:[session valueForKey:@"dbPath"]];
        _manager = [session valueForKey:@"manager"];
        _session = session;
    }
    return self;
}

- (void)handshake:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Initializing synchronization session");

    [_manager POST:_session[kAIQSessionStartDataSyncUrl] parameters:nil success:^(id operation, NSDictionary *json) {
        [self copyLinks:json];
        [self pull:success failure:failure];
    } failure:^(id operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

- (void)pull:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Pulling remote changes");

    [_manager GET:_session[kAIQSessionDownloadUrl] parameters:nil success:^(id operation, NSDictionary *json) {
        [self copyLinks:json];
        [self handlePull:json[@"changes"] success:success failure:failure];
    } failure:^(id operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

- (void)push:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Pushing local changes");

    if (success) {
        success();
    }
}

- (void)handleError:(NSError *)error callback:(void (^)(NSError *))callback {
    if (error.code == NSURLErrorCancelled) {
        AIQLogCInfo(1, @"Did cancel synchronization");
        return;
    }

    NSError *localError;
    NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
    if (response) {
        AIQLogCError(1, @"Did fail to synchronize: %lu", (unsigned long)response.statusCode);
        if (response.statusCode == 401) {
            AIQLogCWarn(1, @"User not authorized");
            [self cancel];
            [_session close:nil failure:nil];
            _manager = nil;
            _session = nil;
            localError = [AIQError errorWithCode:AIQErrorUnauthorized message:@"User not authorized"];
        } else if (response.statusCode == 410) {
            AIQLogCWarn(1, @"Synchronization session no longer valid");
            [self cancel];
            _session[kAIQSessionDownloadUrl] = nil;
            localError = [AIQError errorWithCode:AIQErrorGone message:@"Synchronization session invalid"];
        }
    } else  {
        localError = error;
    }

    if (callback) {
        callback(localError);
    }
}

- (void)handlePull:(NSArray *)changes success:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }
    __block NSError *error = nil;

    AIQLogCInfo(1, @"Did pull %lu remote changes", (unsigned long)changes.count);
    
    [_queue inDatabase:^(FMDatabase *db) {
        for (NSDictionary *change in changes) {
            if (_shouldCancel) {
                return;
            }

            if (! [self processChange:change inDatabase:db error:&error]) {
                return;
            }
        }
    }];

    if (_shouldCancel) {
        return;
    }

    if (! [self queueUnavailableAttachments:&error]) {
        AIQLogCError(1, @"Did fail to queue unavailable attachments: %@", error.localizedDescription);
    }
    
    if (error) {
        AIQLogCError(1, @"Did fail to process remote changes: %@", error.localizedDescription);
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorContainerFault message:error.localizedDescription]);
        }
    } else {
        [self push:success failure:failure];
    }
}

- (BOOL)processChange:(NSDictionary *)change inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    NSString *solution = change[@"_solution"];
    if (! solution) {
        solution = AIQGlobalSolution;
    }
    
    NSString *identifier = change[@"_id"];
    NSString *type = change[@"_type"];
    BOOL deleted = [change[@"_deleted"] boolValue];
    BOOL exists = [self documentWithId:identifier solution:solution existsInDatabase:db];
    
    if (deleted) {
        if (exists) {
            AIQLogCInfo(1, @"Deleting document %@ in solution %@", identifier, solution);
            if (! [self deleteDocumentWithId:identifier type:type solution:solution fromDatabase:db error:error]) {
                return NO;
            }
        } else {
            AIQLogCWarn(1, @"Document %@ does not exist in solution %@, not removing", identifier, solution);
        }
    } else {
        unsigned long long revision = [change[@"_rev"] unsignedLongLongValue];
        NSDictionary *content = change[@"_content"];
        if (! content) {
            NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
            for (NSString *key in change) {
                if ([key characterAtIndex:0] != '_') {
                    filtered[key] = change[key];
                }
                content = filtered;
            }
        }
        
        if (exists) {
            AIQLogCInfo(1, @"Updating document %@ in solution %@", identifier, solution);
            if (! [self updateDocumentWithId:identifier type:type solution:solution revision:revision content:content inDatabase:db error:error]) {
                return NO;
            }
        } else {
            AIQLogCInfo(1, @"Creating document %@ in solution %@", identifier, solution);
            if (! [self createDocumentWithId:identifier type:type solution:solution revision:revision content:content inDatabase:db error:error]) {
                return NO;
            }
        }
        
        if (change[@"_attachments"]) {
            AIQLogCInfo(1, @"Processing attachments of document %@ in solution %@", identifier, solution);
            if (! [self processAttachments:change[@"_attachments"] ofDocumentWithId:identifier type:type solution:solution inDatabase:db error:error]) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)documentWithId:(NSString *)identifier
              solution:(NSString *)solution
      existsInDatabase:(FMDatabase *)db {
    FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        return NO;
    }
    
    BOOL result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
    [rs close];
    
    return result;
}

- (BOOL)createDocumentWithId:(NSString *)identifier
                        type:(NSString *)type
                    solution:(NSString *)solution
                    revision:(unsigned long long)revision
                     content:(NSDictionary *)content
                  inDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:content options:kNilOptions error:nil];
    if (! [db executeUpdate:@"INSERT INTO documents"
           "(solution, identifier, type, revision, synchronizationStatus, content)"
           "VALUES"
           "(?, ?, ?, ?, ?, ?)",
           solution, identifier, type, @(revision), @(AIQSynchronizationStatusSynchronized), data]) {
        *error = [db lastError];
        return NO;
    }
    
    [[self receiverForType:type] didCreateDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)updateDocumentWithId:(NSString *)identifier
                        type:(NSString *)type
                    solution:(NSString *)solution
                    revision:(unsigned long long)revision
                     content:(NSDictionary *)content
                  inDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:content options:kNilOptions error:nil];
    if (! [db executeUpdate:@"UPDATE documents "
           "SET revision = ?, synchronizationStatus = ?, rejectionReason = ?, content = ? "
           "WHERE solution = ? AND identifier = ?",
           @(revision), @(AIQSynchronizationStatusSynchronized), nil, data, solution, identifier]) {
        *error = [db lastError];
        return NO;
    }
    
    [[self receiverForType:type] didUpdateDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)deleteDocumentWithId:(NSString *)identifier
                        type:(NSString *)type
                    solution:(NSString *)solution
                fromDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
        *error = [db lastError];
        return NO;
    }
    
    if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier]) {
        *error = [db lastError];
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    if ([fileManager fileExistsAtPath:path]) {
        if (! [fileManager removeItemAtPath:path error:error]) {
            return NO;
        }
    }
    
    [[self receiverForType:type] didDeleteDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)processAttachments:(NSDictionary *)attachments
          ofDocumentWithId:(NSString *)identifier
                      type:(NSString *)type
                  solution:(NSString *)solution
                inDatabase:(FMDatabase *)db
                     error:(NSError *__autoreleasing *)error {
    NSMutableDictionary *existing = [NSMutableDictionary dictionary];
    FMResultSet *rs = [db executeQuery:@"SELECT name, revision FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        *error = [db lastError];
        return NO;
    }
    
    while ([rs next]) {
        existing[[rs stringForColumnIndex:0]] = [rs objectForColumnIndex:1];
    }
    [rs close];
    
    NSURL *downloadURL = [NSURL URLWithString:_session[kAIQSessionDownloadUrl]];
    
    for (NSString *name in attachments) {
        NSDictionary *attachment = attachments[name];
        
        NSNumber *oldRevision = existing[name];
        NSNumber *newRevision = attachments[@"_rev"];
        
        
        NSString *link = [NSURL URLWithString:attachment[@"links"][@"self"] relativeToURL:downloadURL].absoluteString;
        
        if (oldRevision) {
            [existing removeObjectForKey:name];
            if (newRevision.unsignedLongLongValue > oldRevision.unsignedLongLongValue) {
                AIQLogCInfo(1, @"Attachment %@ for document %@ in solution %@ is newer", name, identifier, solution);
                if (! [self updateAttachmentWithName:name
                                         contentType:attachment[@"content_type"]
                                                link:link
                                            revision:newRevision.unsignedIntegerValue
                                   forDocumentWithId:identifier
                                                type:type
                                            solution:solution
                                          inDatabase:db
                                               error:error]) {
                    return NO;
                }
            } else {
                AIQLogCInfo(1, @"Attachment %@ for document %@ in solution %@ is up to date", name, identifier, solution);
            }
        } else {
            AIQLogCInfo(1, @"Attachment %@ for document %@ in solution %@ is new", name, identifier, solution);
            if (! [self createAttachmentWithName:name
                                     contentType:attachment[@"content_type"]
                                            link:link
                                        revision:newRevision.unsignedLongLongValue
                               forDocumentWithId:identifier
                                            type:type
                                        solution:solution
                                      inDatabase:db
                                           error:error]) {
                return NO;
            }
        }
    }
    
    for (NSString *name in existing) {
        AIQLogCInfo(1, @"Deleting attachment %@ for document %@ in solution %@", name, identifier, solution);
        if (! [self deleteAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution fromDatabase:db error:error]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)createAttachmentWithName:(NSString *)name
                     contentType:(NSString *)contentType
                            link:(NSString *)link
                        revision:(unsigned long long)revision
               forDocumentWithId:(NSString *)identifier
                            type:(NSString *)type
                        solution:(NSString *)solution
                      inDatabase:(FMDatabase *)db
                           error:(NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"INSERT INTO attachments"
           "(solution, identifier, name, revision, contentType, link, state, synchronizationStatus)"
           "VALUES"
           "(?, ?, ?, ?, ?, ?, ?, ?)",
           solution, identifier, name, @(revision), contentType, link, @(AIQAttachmentStateUnavailable), @(AIQSynchronizationStatusSynchronized)]) {
        *error = [db lastError];
        return NO;
    }
    
    [[self receiverForType:type] didCreateAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)updateAttachmentWithName:(NSString *)name
                     contentType:(NSString *)contentType
                            link:(NSString *)link
                        revision:(unsigned long long)revision
               forDocumentWithId:(NSString *)identifier
                            type:(NSString *)type
                        solution:(NSString *)solution
                      inDatabase:(FMDatabase *)db
                           error:(NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"UPDATE attachments "
           "SET revision = ?, contentType = ?, link = ?, state = ?, synchronizationStatus = ?, rejectionReason = ?"
           "WHERE solution = ? AND identifier = ? AND name = ?",
           @(revision), contentType, link, @(AIQAttachmentStateUnavailable), @(AIQSynchronizationStatusSynchronized), solution, identifier, name]) {
        *error = [db lastError];
        return NO;
    }
    
    [[self receiverForType:type] didUpdateAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)deleteAttachmentWithName:(NSString *)name
               forDocumentWithId:(NSString *)identifier
                            type:(NSString *)type
                        solution:(NSString *)solution
                    fromDatabase:(FMDatabase *)db
                           error:(NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", solution, identifier, name]) {
        *error = [db lastError];
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
    if ([fileManager fileExistsAtPath:path]) {
        if (! [fileManager removeItemAtPath:path error:error]) {
            return NO;
        }
    }
    
    [[self receiverForType:type] didDeleteAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)queueUnavailableAttachments:(NSError *__autoreleasing *)error {
    __block BOOL result = YES;

    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT a.solution, a.identifier, a.name, a.revision, a.link, d.type "
                           "FROM attachments a, documents d "
                           "WHERE a.solution = d.solution AND a.identifier = d.identifier AND a.state = ?",
                           @(AIQAttachmentStateUnavailable)];
        if (! rs) {
            *error = [db lastError];
            result = NO;
            return;
        }

        while ([rs next]) {
            if (! [self queueAttachmentWithName:[rs stringForColumnIndex:2]
                                           link:[rs stringForColumnIndex:4]
                                       revision:[rs unsignedLongLongIntForColumnIndex:3]
                              forDocumentWithId:[rs stringForColumnIndex:1]
                                           type:[rs stringForColumnIndex:5]
                                       solution:[rs stringForColumnIndex:0]
                                          error:error]) {
                result = NO;
            }
        }

        [rs close];
    }];

    return result;
}

- (BOOL)queueAttachmentWithName:(NSString *)name
                           link:(NSString *)link
                       revision:(unsigned long long)revision
              forDocumentWithId:(NSString *)identifier
                           type:(NSString *)type
                       solution:(NSString *)solution
                          error:(NSError *__autoreleasing *)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *folderPath = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    NSString *filePath = [folderPath stringByAppendingPathComponent:name];
    NSString *tmpPath = [filePath stringByAppendingPathExtension:@"tmp"];
    BOOL append = NO;
    NSMutableURLRequest *request = [_manager.requestSerializer requestWithMethod:@"GET" URLString:link parameters:nil error:error];
    if ([fileManager fileExistsAtPath:tmpPath]) {
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:tmpPath error:error];
        if (attributes) {
            [request setValue:[NSString stringWithFormat:@"Range: bytes=%llu-", attributes.fileSize] forHTTPHeaderField:@"Range"];
            [request setValue:[NSString stringWithFormat:@"%llu", revision] forHTTPHeaderField:@"If-Range"];
            append = YES;
        } else {
            return NO;
        }
    } else {
        if(! [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:@{} error:error]) {
            return NO;
        }
    }
    
    id<SynchronizationReceiver> receiver = [self receiverForType:type];

    AFHTTPRequestOperation *operation = [_manager HTTPRequestOperationWithRequest:request success:^(id operation, id data) {
        NSError *error = nil;
        if ([fileManager fileExistsAtPath:filePath]) {
            if (! [fileManager removeItemAtPath:filePath error:&error]) {
                AIQLogCError(1, @"Did fail to delete attachment file %@ for document %@ in solution %@: %@",
                             name, identifier, solution, error.localizedDescription);
                return;
            }
        }
        if (! [fileManager moveItemAtPath:tmpPath toPath:filePath error:&error]) {
            AIQLogCError(1, @"Did fail to move attachment file %@ for document %@ in solution %@: %@",
                         name, identifier, solution, error.localizedDescription);
            return;
        }
        [self updateAttachmentState:AIQAttachmentStateAvailable
               ofAttachmentWithName:name
                  forDocumentWithId:identifier
                               type:type
                           solution:solution];
    } failure:^(id operation, NSError *error) {
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        AIQAttachmentState state;
        if ((response) && (response.statusCode < 500)) {
            state = AIQAttachmentStateFailed;
        } else {
            state = AIQAttachmentStateUnavailable;
        }
        [self updateAttachmentState:state ofAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution];
        [self handleError:error callback:nil];
    }];

    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        [receiver didProgressAttachmentWithName:name
                                     downloaded:totalBytesRead
                                          total:totalBytesExpectedToRead
                              forDocumentWithId:identifier
                                           type:type
                                       solution:solution];
    }];
    operation.outputStream = [NSOutputStream outputStreamToFileAtPath:tmpPath append:append];
    [_manager.operationQueue addOperation:operation];

    return YES;
}

- (void)updateAttachmentState:(AIQAttachmentState)state
         ofAttachmentWithName:(NSString *)name
            forDocumentWithId:(NSString *)identifier
                         type:(NSString *)type
                     solution:(NSString *)solution {
    [_queue inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"UPDATE attachments SET state = ? WHERE solution = ? AND identifier = ? AND name = ?",
               @(state), solution, identifier, name]) {
            AIQLogCError(1, @"Did fail to update state of attachment t%@ for document %@ in solution %@: %@",
                         name, identifier, solution, [db lastError].localizedDescription);
            return;
        }
        [[self receiverForType:type] didChangeState:state
                               ofAttachmentWithName:name
                                  forDocumentWithId:identifier
                                               type:type
                                           solution:solution];
    }];
}

- (void)copyLinks:(NSDictionary *)json {
    NSDictionary *links = json[@"links"];
    if (links[@"nextDownload"]) {
        _session[kAIQSessionDownloadUrl] = links[@"nextDownload"];
    } else if (links[@"download"]) {
        _session[kAIQSessionDownloadUrl] = links[@"download"];
    }
    if (links[@"nextUpload"]) {
        _session[kAIQSessionUploadUrl] = links[@"nextUpload"];
    } else if (links[@"upload"]) {
        _session[kAIQSessionUploadUrl] = links[@"upload"];
    }
    if (links[@"nextAttachments"]) {
        _session[kAIQSessionAttachmentsUrl] = links[@"nextAttachments"];
    } else if (links[@"attachments"]) {
        _session[kAIQSessionAttachmentsUrl] = links[@"attachments"];
    }
    if (links[@"nextPush"]) {
        _session[kAIQSessionPushUrl] = links[@"nextPush"];
    } else if (links[@"push"]) {
        _session[kAIQSessionPushUrl] = links[@"push"];
    }
    [_session storeProperties];
}

- (void)close {
    if (_manager) {
        [_manager.operationQueue cancelAllOperations];
        _manager = nil;
    }

    if (_queue) {
        [_queue close];
        _queue = nil;
    }

    _session = nil;
}

- (BOOL)isInternal:(NSString *)type {
    return [type characterAtIndex:0] == '_';
}

- (id<SynchronizationReceiver>)receiverForType:(NSString *)type {
    if (! _synchronizationReceivers) {
        return self;
    }
    
    id<SynchronizationReceiver> receiver = _synchronizationReceivers[type];
    if (! receiver) {
        return self;
    }
    
    return receiver;
}

@end
