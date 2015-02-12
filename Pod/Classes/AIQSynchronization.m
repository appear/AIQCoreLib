/*
 The MIT License (MIT)

 Copyright (c) 2015 Appear Networks AB

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <mach/mach_host.h>

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
NSString *const AIQDidSynchronizeDocumentNotification = @"AIQDidSynchronizeDocumentNotification";
NSString *const AIQDidRejectDocumentNotification = @"AIQDidRejectDocumentNotification";

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
NSString *const AIQRejectionReasonUserInfoKey = @"AIQRejectionReasonUserInfoKey";

@interface AIQSession ()

- (void)storeProperties;

@end

@interface AIQSynchronization () <SynchronizationReceiver> {
    NSString *_basePath;
    NSNotificationCenter *_center;
    FMDatabaseQueue *_queue;
    AFHTTPRequestOperationManager *_documentManager;
    AFHTTPRequestOperationManager *_attachmentManager;
    AIQSession *_session;
    NSMutableDictionary *_synchronizationReceivers;
    BOOL _shouldCancel;
    NSUInteger _protocolVersion;
    NSFileManager *_fileManager;
}

@end

@implementation AIQSynchronization

- (void)synchronize:(void (^)(void))success failure:(void (^)(NSError *))failure {
    AIQLogCInfo(1, @"Synchronizing");

    void (^block)(void) = ^{
        [self pull:^{
            [self push:success failure:failure];
        } failure:failure];
    };

    if (! _session[kAIQSessionDownloadUrl]) {
        block = ^{
            [self handshake:block failure:failure];
        };
    }

    _shouldCancel = NO;
    block();
}

- (void)cancel {
    AIQLogCInfo(1, @"Cancelling");

    [_documentManager.operationQueue cancelAllOperations];
    [_attachmentManager.operationQueue cancelAllOperations];
    _shouldCancel = YES;
}

#pragma mark - SynchronizationReceiver

- (void)didCreateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidCreateDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                                  AIQDocumentTypeUserInfoKey: type,
                                                                                                  AIQSolutionUserInfoKey: solution}];
        });
    }
}
- (void)didUpdateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidUpdateDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                                  AIQDocumentTypeUserInfoKey: type,
                                                                                                  AIQSolutionUserInfoKey: solution}];
        });
    }
}
- (void)didDeleteDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidDeleteDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                                  AIQDocumentTypeUserInfoKey: type,
                                                                                                  AIQSolutionUserInfoKey: solution}];
        });
    }
}

- (void)didSynchronizeDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidSynchronizeDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                                       AIQDocumentTypeUserInfoKey: type,
                                                                                                       AIQSolutionUserInfoKey: solution}];
        });
    }
}

- (void)didRejectDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidRejectDocumentNotification object:self userInfo:@{AIQDocumentIdUserInfoKey: identifier,
                                                                                                  AIQDocumentTypeUserInfoKey: type,
                                                                                                  AIQSolutionUserInfoKey: solution,
                                                                                                  AIQRejectionReasonUserInfoKey: @(reason)}];
        });
    }
}

- (void)didCreateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidSynchronizeDocumentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                       AIQDocumentIdUserInfoKey: identifier,
                                                                                                       AIQDocumentTypeUserInfoKey: type,
                                                                                                       AIQSolutionUserInfoKey: solution}];
        });
    }
}
- (void)didUpdateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidUpdateAttachmentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                    AIQDocumentIdUserInfoKey: identifier,
                                                                                                    AIQDocumentTypeUserInfoKey: type,
                                                                                                    AIQSolutionUserInfoKey: solution}];
        });
    }
}

- (void)didDeleteAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    if (! [self isInternal:type]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_center postNotificationName:AIQDidDeleteAttachmentNotification object:self userInfo:@{AIQAttachmentNameUserInfoKey: name,
                                                                                                    AIQDocumentIdUserInfoKey: identifier,
                                                                                                    AIQDocumentTypeUserInfoKey: type,
                                                                                                    AIQSolutionUserInfoKey: solution}];
        });
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
    if (! session) {
        return nil;
    }

    if (! [session isOpen]) {
        return nil;
    }

    self = [super init];
    if (self) {
        _basePath = [session valueForKey:@"basePath"];
        _center = [NSNotificationCenter defaultCenter];
        _queue = [FMDatabaseQueue databaseQueueWithPath:[session valueForKey:@"dbPath"]];
        _session = session;
        _protocolVersion = [session[kAIQSessionProtocolVersion] unsignedIntegerValue];

        _documentManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:_session[kAIQSessionBaseURL]]];
        _documentManager.responseSerializer = [AFJSONResponseSerializer serializer];

        AFHTTPRequestSerializer *requestSerializer = [AFJSONRequestSerializer serializer];
        [requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _session[kAIQSessionAccessToken]] forHTTPHeaderField:@"Authorization"];
        _documentManager.requestSerializer = requestSerializer;

        host_basic_info_data_t hostInfo;
        mach_msg_type_number_t infoCount;

        infoCount = HOST_BASIC_INFO_COUNT;
        host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
        AIQLogCInfo(1, @"Setting size to %d for attachment queue", MAX(2, hostInfo.max_cpus * hostInfo.max_cpus));

        _attachmentManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:_session[kAIQSessionBaseURL]]];
        _attachmentManager.operationQueue.maxConcurrentOperationCount = MAX(2, hostInfo.max_cpus * hostInfo.max_cpus);
        [_attachmentManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _session[kAIQSessionAccessToken]] forHTTPHeaderField:@"Authorization"];
        _attachmentManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        _fileManager = [NSFileManager new];
    }
    return self;
}

#pragma mark - Handshake

- (void)handshake:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Initializing synchronization session");

    [_documentManager POST:_session[kAIQSessionStartDataSyncUrl] parameters:nil success:^(id operation, NSDictionary *json) {
        [self copyLinks:json];

        if (success) {
            success();
        }
    } failure:^(id operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

#pragma mark - Platform to client

- (void)pull:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Pulling remote changes");

    [_documentManager GET:_session[kAIQSessionDownloadUrl] parameters:nil success:^(id operation, NSDictionary *json) {
        [self copyLinks:json];
        [self handlePull:json[@"changes"] success:success failure:failure];
    } failure:^(id operation, NSError *error) {
        [self handleError:error callback:failure];
    }];
}

- (void)handlePull:(NSArray *)changes success:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    if (changes.count == 0) {
        AIQLogCInfo(1, @"No remote changes to process");

        if (success) {
            success();
        }

        return;
    }

    AIQLogCInfo(1, @"Did pull %lu remote changes", (unsigned long)changes.count);

    __block NSError *error = nil;

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

    if (error) {
        AIQLogCError(1, @"Did fail to process remote changes: %@", error.localizedDescription);
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorContainerFault message:error.localizedDescription]);
        }
    } else {
        if (success) {
            success();
        }
    }
}

- (BOOL)processChange:(NSDictionary *)change inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    NSString *solution = (_protocolVersion == 0) ? AIQGlobalSolution : change[@"_solution"];
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
        NSNumber *revision = change[@"_rev"];
        NSDictionary *content;
        if (_protocolVersion == 0) {
            NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
            for (NSString *key in change) {
                if ([key characterAtIndex:0] != '_') {
                    filtered[key] = change[key];
                }
                content = filtered;
            }
        } else {
            content = change[@"_content"];
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

- (unsigned long long)revisionOfDocumentWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db {
    FMResultSet *rs = [db executeQuery:@"SELECT revision FROM documents WHERE solution = ? AND identifier = ?",
                       solution, identifier];
    if (! rs) {
        return 0l;
    }

    unsigned long long revision = [rs next] ? [rs unsignedLongLongIntForColumnIndex:0] : 0ull;
    [rs close];

    return revision;
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
                    revision:(NSNumber *)revision
                     content:(NSDictionary *)content
                  inDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:content options:kNilOptions error:nil];
    if (! [db executeUpdate:@"INSERT INTO documents"
           "(solution, identifier, type, revision, synchronizationStatus, content)"
           "VALUES"
           "(?, ?, ?, ?, ?, ?)",
           solution, identifier, type, revision, @(AIQSynchronizationStatusSynchronized), data]) {
        *error = [db lastError];
        return NO;
    }

    [[self receiverForType:type] didCreateDocumentWithId:identifier type:type solution:solution];

    return YES;
}

- (BOOL)updateDocumentWithId:(NSString *)identifier
                        type:(NSString *)type
                    solution:(NSString *)solution
                    revision:(NSNumber *)revision
                     content:(NSDictionary *)content
                  inDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:content options:kNilOptions error:nil];
    if (! [db executeUpdate:@"UPDATE documents "
           "SET revision = ?, synchronizationStatus = ?, rejectionReason = ?, content = ? "
           "WHERE solution = ? AND identifier = ?",
           revision, @(AIQSynchronizationStatusSynchronized), nil, data, solution, identifier]) {
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

    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    if ([_fileManager fileExistsAtPath:path]) {
        if (! [_fileManager removeItemAtPath:path error:error]) {
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

    for (NSString *name in attachments) {
        NSDictionary *attachment = attachments[name];

        NSNumber *oldRevision = existing[name];
        NSNumber *newRevision = attachments[@"_rev"];

        if (oldRevision) {
            [existing removeObjectForKey:name];
            if (newRevision.unsignedLongLongValue > oldRevision.unsignedLongLongValue) {
                AIQLogCInfo(1, @"Attachment %@ for document %@ in solution %@ is newer", name, identifier, solution);
                if (! [self updateAttachmentWithName:name
                                         contentType:attachment[@"content_type"]
                                                link:attachment[@"links"][@"self"]
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
                                            link:attachment[@"links"][@"self"]
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

    NSString *path = [[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
    if ([_fileManager fileExistsAtPath:path]) {
        if (! [_fileManager removeItemAtPath:path error:error]) {
            return NO;
        }
    }

    [[self receiverForType:type] didDeleteAttachmentWithName:name forDocumentWithId:identifier type:type solution:solution];
    
    return YES;
}

#pragma mark - Client to platform

- (void)push:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Pushing local changes");

    __block NSMutableArray *docs = nil;
    __block NSError *error = nil;

    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT solution, identifier, type, revision, content, synchronizationStatus FROM documents "
                           "WHERE synchronizationStatus NOT IN (?, ?)",
                           @(AIQSynchronizationStatusSynchronized), @(AIQSynchronizationStatusRejected)];
        if (! rs) {
            error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            return;
        }

        docs = [NSMutableArray array];

        while ([rs next]) {
            if (_shouldCancel) {
                break;
            }
            AIQSynchronizationStatus status = [rs intForColumnIndex:5];
            NSMutableDictionary *doc = [NSMutableDictionary dictionary];
            doc[@"_solution"] = [rs stringForColumnIndex:0];
            doc[@"_id"] = [rs stringForColumnIndex:1];
            doc[@"_type"] = [rs stringForColumnIndex:2];
            if (status == AIQSynchronizationStatusDeleted) {
                doc[@"_rev"] = [rs objectForColumnIndex:3];
                doc[@"_deleted"] = @YES;
            } else {
                if (status == AIQSynchronizationStatusUpdated) {
                    doc[@"_rev"] = [rs objectForColumnIndex:3];
                }
                NSDictionary *content = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:4] options:kNilOptions error:nil];
                if (_protocolVersion == 0) {
                    for (NSString *field in content) {
                        doc[field] = content[field];
                    }
                } else {
                    doc[@"_content"] = content;
                }
            }
            [docs addObject:doc];
        }

        [rs close];
    }];

    if (_shouldCancel)  {
        return;
    }

    if ((error) && (failure)) {
        failure(error);
        return;
    }

    if (docs.count == 0) {
        AIQLogCInfo(1, @"No local changes to upload");
        if (success) {
            success();
        }
    } else {
        AIQLogCInfo(1, @"Uploading %lu local changes", (unsigned long)docs.count);
        [_documentManager POST:_session[kAIQSessionUploadUrl] parameters:@{@"docs": docs} success:^(id operation, NSDictionary *json) {
            [self copyLinks:json];
            [self handlePush:json[@"results"] success:success failure:failure];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self handleError:error callback:failure];
        }];

        if (success) {
            success();
        }
    }
}

- (void)handlePush:(NSArray *)results success:(void (^)(void))success failure:(void (^)(NSError *))failure {
    if (_shouldCancel) {
        return;
    }

    AIQLogCInfo(1, @"Did receive %lu results", (unsigned long)results.count);

    __block NSError *error = nil;

    [_queue inDatabase:^(FMDatabase *db) {
        for (NSDictionary *result in results) {
            if (_shouldCancel) {
                return;
            }

            if (! [self processResult:result inDatabase:db error:&error]) {
                return;
            }
        }
    }];

    if (_shouldCancel) {
        return;
    }

    if (error) {
        AIQLogCError(1, @"Did fail to process results: %@", error.localizedDescription);
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorContainerFault message:error.localizedDescription]);
        }
    } else {
        if (success) {
            success();
        }
    }
}

- (BOOL)processResult:(NSDictionary *)result inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    NSString *solution = (_protocolVersion == 0) ? AIQGlobalSolution : result[@"_solution"];
    NSString *identifier = result[@"_id"];

    NSDictionary *info = [self infoOfDocumentWithId:identifier solution:solution inDatabase:db error:error];

    if (! info) {
        return NO;
    }

    NSString *type = info[kAIQDocumentType];

    if (result[@"_error"]) {
        return [self processPushError:[result[@"_error"] integerValue]
                    forDocumentWithId:identifier
                                 type:type
                             solution:solution
                           inDatabase:db error:error];
    }

    AIQSynchronizationStatus status = [info[kAIQDocumentSynchronizationStatus] integerValue];
    if (status == AIQSynchronizationStatusDeleted) {
        if (! [self deleteDocumentWithId:identifier solution:solution inDatabase:db error:error]) {
            return NO;
        }
    } else {
        if (! [self updateRevision:result[@"_rev"] ofDocumentWithId:identifier solution:solution inDatabase:db error:error]) {
            return NO;
        }
    }

    [[self receiverForType:type] didSynchronizeDocumentWithId:identifier type:type solution:solution];

    return YES;
}

- (BOOL)updateRevision:(NSNumber *)revision
      ofDocumentWithId:(NSString *)identifier
              solution:(NSString *)solution
            inDatabase:(FMDatabase *)db
                 error:(NSError *__autoreleasing *)error {
    AIQLogCInfo(1, @"Document %@ was updated locally, changing revision to %@", identifier, revision);
    
    if (! [db executeUpdate:@"UPDATE documents SET synchronizationStatus = ?, revision = ? WHERE solution = ? AND identifier = ?",
           @(AIQSynchronizationStatusSynchronized), revision, solution, identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)deleteDocumentWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    AIQLogCInfo(1, @"Document %@ was deleted locally, removing", identifier);
    
    if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    if ([_fileManager fileExistsAtPath:path]) {
        NSError *localError = nil;
        if (! [_fileManager removeItemAtPath:path error:&localError]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
            }
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)processPushError:(NSUInteger)statusCode
       forDocumentWithId:(NSString *)identifier
                    type:(NSString *)type
                solution:(NSString *)solution
              inDatabase:(FMDatabase *)db
                   error:(NSError *__autoreleasing *)error {
    AIQRejectionReason reason = AIQRejectionReasonUnknown;
    if ((statusCode >= 400) && (statusCode <= 499)) {
        if (statusCode == 403) {
            AIQLogCInfo(1, @"Permission denied for document %@", identifier);
            reason = AIQRejectionReasonPermissionDenied;
        } else if (statusCode == 404) {
            AIQLogCInfo(1, @"Document type %@ not recognized for document %@", type, identifier);
            reason = AIQRejectionReasonTypeNotFound;
        } else if (statusCode == 405) {
            AIQLogCInfo(1, @"Operation not allowed for document %@ with type %@", identifier, type);
            reason = AIQRejectionReasonRestrictedType;
        } else if (statusCode == 409) {
            AIQLogCInfo(1, @"Document %@ already exists", identifier);
            reason = AIQRejectionReasonCreateConflict;
        } else if (statusCode == 412) {
            AIQLogCInfo(1, @"Revision conflict for document %@", identifier);
            reason = AIQRejectionReasonUpdateConflict;
        }
        
        if (! [db executeUpdate:@"UPDATE documents SET synchronizationStatus = ?, rejectionReason = ? WHERE solution = ? AND identifier = ?",
               @(AIQSynchronizationStatusRejected), @(reason), solution, identifier]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return NO;
        }
        
        [[self receiverForType:type] didRejectDocumentWithId:identifier type:type solution:solution reason:reason];
    } else {
        AIQLogCWarn(1, @"Document %@ temporarily failed to synchronize: %lu", identifier, (unsigned long)statusCode);
    }
    
    return YES;
}

- (NSDictionary *)infoOfDocumentWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    FMResultSet *rs = [db executeQuery:@"SELECT type, synchronizationStatus FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return nil;
    }

    NSDictionary *info = nil;

    if ([rs next]) {
        info = @{kAIQDocumentType: [rs stringForColumnIndex:0],
                 kAIQDocumentSynchronizationStatus: [rs objectForColumnIndex:1]};
    } else {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
        }
    }
    [rs close];
    
    return info;
}

#pragma mark - Other

- (void)handleError:(NSError *)error callback:(void (^)(NSError *))callback {
    if (error.code == NSURLErrorCancelled) {
        AIQLogCInfo(1, @"Did cancel synchronization");
        return;
    }

    NSError *localError;
    NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
    if (response) {
        if (response.statusCode == 401) {
            AIQLogCWarn(1, @"User not authorized");
            [self close];
            [_session close:nil failure:nil];
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
    if (_documentManager) {
        [_documentManager.operationQueue cancelAllOperations];
        _documentManager = nil;
    }

    if (_attachmentManager) {
        [_attachmentManager.operationQueue cancelAllOperations];
        _attachmentManager = nil;
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
