#import <FMDB/FMDB.h>
#import <mach/mach_host.h>

#import "AIQDataStore.h"
#import "AIQOperation.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "AIQSynchronizer.h"
#import "DeleteOperation.h"
#import "DownloadOperation.h"
#import "UploadOperation.h"
#import "GZIP.h"
#import "common.h"

NSTimeInterval const AIQSynchronizationDocumentTimeout = 60.0f;
NSTimeInterval const AIQSynchronizationAttachmentTimeout = 15.0f;

NSString *const AIQSynchronizationAttachmentProgressKey = @"AIQSynchronizationAttachmentProgress";
NSString *const AIQSynchronizationRejectionReasonKey = @"AIQSynchronizationRejectionReason";
NSString *const AIQSynchronizationErrorCodeKey = @"AIQSynchronizationErrorCode";

NSString *const AIQSynchronizationResponseCodeKey = @"AIQSynchronizationResponseCode";

NSInteger const AIQSynchronizationGoneError = 4001;

NSString *const AIQSolutionUserInfoKey = @"AIQSolutionUserInfoKey";
NSString *const AIQDocumentIdUserInfoKey = @"AIQDocumentIdUserInfoKey";
NSString *const AIQDocumentTypeUserInfoKey = @"AIQDocumentTypeUserInfoKey";
NSString *const AIQAttachmentNameUserInfoKey = @"AIQAttachmentNameUserInfoKey";
NSString *const AIQAttachmentProgressUserInfoKey = @"AIQAttachmentProgressUserInfoKey";
NSString *const AIQRejectionReasonUserInfoKey = @"AIQRejectionReasonUserInfoKey";
NSString *const AIQErrorCodeUserInfoKey = @"AIQErrorCodeUserInfoKey";
NSString *const AIQSynchronizationStatusUserInfoKey = @"AIQSynchronizationStatusUserInfoKey";

NSString *const AIQDidCreateDocumentNotification = @"AIQDidCreateDocumentNotification";
NSString *const AIQDidUpdateDocumentNotification = @"AIQDidUpdateDocumentNotification";
NSString *const AIQDidDeleteDocumentNotification = @"AIQDidDeleteDocumentNotification";
NSString *const AIQDidSynchronizeDocumentNotification = @"AIQDidSynchronizeDocumentNotification";
NSString *const AIQDidRejectDocumentNotification = @"AIQDidRejectDocumentNotification";
NSString *const AIQDocumentErrorNotification = @"AIQDocumentErrorNotification";

NSString *const AIQDidCreateAttachmentNotification = @"AIQDidCreateAttachmentNotification";
NSString *const AIQDidUpdateAttachmentNotification = @"AIQDidUpdateAttachmentNotification";
NSString *const AIQDidDeleteAttachmentNotification = @"AIQDidDeleteAttachmentNotification";
NSString *const AIQWillDownloadAttachmentNotification = @"AIQWillDownloadAttachmentNotification";
NSString *const AIQAttachmentDidBecomeAvailableNotification = @"AIQAttachmentDidBecomeAvailableNotification";
NSString *const AIQAttachmentDidBecomeUnavailableNotification = @"AIQAttachmentDidBecomeUnavailableNotification";
NSString *const AIQAttachmentDidFailNotification = @"AIQAttachmentDidFailNotification";
NSString *const AIQAttachmentDidProgressNotification = @"AIQAttachmentDidProgressNotification";
NSString *const AIQDidSynchronizeAttachmentNotification = @"AIQDidSynchronizeAttachmentNotification";
NSString *const AIQDidRejectAttachmentNotification = @"AIQDidRejectAttachmentNotification";
NSString *const AIQAttachmentErrorNotification = @"AIQAttachmentErrorNotification";

@interface AIQSession ()

- (void)synchronizeProperties;

@end

@interface AIQSynchronization () <AIQSynchronizer> {
    AIQSession *_session;
    NSURLConnection *_connection;
    NSMutableData *_data;
    NSInteger _statusCode;
    NSOperationQueue *_downloadQueue;
    NSOperationQueue *_uploadQueue;
    BOOL _shouldCancel;
    NSString *_basePath;
    FMDatabaseQueue *_dbQueue;
    NSMutableDictionary *_synchronizers;
}

@end

@implementation AIQSynchronization

- (instancetype)initForSession:(AIQSession *)session {
    self = [super init];
    if (self) {
        _session = session;
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[session valueForKey:@"dbPath"]];
        _basePath = [session valueForKey:@"basePath"];
        
        host_basic_info_data_t hostInfo;
        mach_msg_type_number_t infoCount;
        
        infoCount = HOST_BASIC_INFO_COUNT;
        host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
        AIQLogCInfo(1, @"Setting size to %d for download queue", MAX(2, hostInfo.max_cpus * hostInfo.max_cpus));
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = MIN(8, MAX(2, hostInfo.max_cpus * hostInfo.max_cpus));
        
        _uploadQueue = [NSOperationQueue new];
        _uploadQueue.maxConcurrentOperationCount = 1;
        
        _documentTimeout = AIQSynchronizationDocumentTimeout;
        _attachmentTimeout = AIQSynchronizationAttachmentTimeout;
    }
    return self;
}

- (BOOL)synchronize:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        if (_connection) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Already synchronizing"];
            }
            return NO;
        }
        if (! [_session isOpen]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Session closed"];
            }
            return NO;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            AIQLogCInfo(1, @"Waiting for upload operations");
            [_uploadQueue waitUntilAllOperationsAreFinished];
            AIQLogCInfo(1, @"Upload operations ready, proceeding with download");
            
            NSString *url = [_session propertyForName:@"download"];
            
            _shouldCancel = NO;
            if (url) {
                [self pull];
            } else {
                // we have to handshake first
                [self handshake];
            }
        });
        
        return YES;
    }
}

- (void)synchronouslyHandshake:(void (^)(AIQSynchronizationResult))handler {
    AIQLogCInfo(1, @"Synchronously handshaking");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_session propertyForName:@"startdatasync"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_documentTimeout];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (! data) {
        handler(AIQSynchronizationResultFailed);
        return;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (! json) {
        handler(AIQSynchronizationResultFailed);
        return;
    }
    [self storeLinks:json[@"links"]];
    [self synchronouslyPull:handler];
}

- (void)synchronouslyPull:(void (^)(AIQSynchronizationResult))handler {
    AIQLogCInfo(1, @"Synchronously pulling");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_session propertyForName:@"download"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_documentTimeout];
    request.HTTPMethod = @"GET";
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    NSURLResponse *response = nil;
    __block NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (! data) {
        handler(AIQSynchronizationResultFailed);
        return;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (! json) {
        handler(AIQSynchronizationResultFailed);
        return ;
    }
    [self storeLinks:json[@"links"]];

    NSArray *changes = json[@"changes"];
    if (changes.count == 0) {
        AIQLogCInfo(1, @"No remote changes to process");
        handler(AIQSynchronizationResultNoData);
        return;
    }

    [_dbQueue inDatabase:^(FMDatabase *db) {
        AIQLogCInfo(1, @"Processing %lu changes", (unsigned long)changes.count);

        NSFileManager *fileManager = [NSFileManager defaultManager];

        for (NSDictionary *change in changes) {
            NSString *solution = change[@"_solution"];
            if (! solution) {
                solution = @"_global";
            }

            NSString *identifier = change[@"_id"];
            NSString *type = change[@"_type"];
            BOOL exists = [self documentWithId:identifier forSolution:solution existsInDatabase:db];
            BOOL deleted = [change[@"_deleted"] boolValue];

            if (deleted) {
                // TODO: workaround for backend bug
                if (! [type isEqualToString:@"_clientcontext"]) {
                    if (exists) {
                        if (! [self deleteDocumentWithId:identifier andType:type forSolution:solution fileManager:fileManager fromDatabase:db error:&error]) {
                            handler(AIQSynchronizationResultFailed);
                            return;
                        }
                    }
                }
            } else {
                if (exists) {
                    if (! [self updateDocumentWithId:identifier andType:type forSolution:solution usingChange:change fileManager:fileManager inDatabase:db error:&error]) {
                        handler(AIQSynchronizationResultFailed);
                        return;
                    }
                } else {
                    if (! [self insertDocumentWithId:identifier andType:type forSolution:solution usingChange:change intoDatabase:db error:&error]) {
                        handler(AIQSynchronizationResultFailed);
                        return;
                    }
                }

                NSDictionary *attachments = change[@"_attachments"];
                if (! attachments) {
                    continue;
                }

                for (NSString *name in attachments.allKeys) {
                    NSDictionary *attachment = attachments[name];
                    long long newRevision = [attachment[@"_rev"] longLongValue];
                    long long oldRevision = [self revisionOfAttachmentWithName:name forDocumentWithId:identifier forSolution:solution inDatabase:db error:&error];
                    if (oldRevision == -1) {
                        AIQLogCError(1, @"Could not retrieve revision for document %@: %@", identifier, error.localizedDescription);
                        handler(AIQSynchronizationResultFailed);
                        return;
                    } else if (newRevision == oldRevision) {
                        NSURL *url = [NSURL URLWithString:[_session propertyForName:@"download"]];
                        url = [NSURL URLWithString:attachment[@"links"][@"self"] relativeToURL:url];
                        AIQLogCInfo(1, @"Updating link for attachment %@ in document %@", name, identifier);
                        if (! [db executeUpdate:@"UPDATE attachments SET link = ? WHERE solution = ? AND identifier = ? AND name = ?", url.absoluteString, solution, identifier, name]) {
                            AIQLogCError(1, @"Did fail to update attachment %@ for document %@: %@", name, identifier, [db lastError].localizedDescription);
                            handler(AIQSynchronizationResultFailed);
                            return;
                        }
                    } else if (newRevision > oldRevision) {
                        if (oldRevision == 0l) {
                            AIQLogCInfo(1, @"Attachment %@ in document %@ is new, adding to pool", name, identifier);
                        } else {
                            AIQLogCInfo(1, @"Attachment %@ in document %@ is newer, adding to pool", name, identifier);
                        }
                        NSURL *url = [NSURL URLWithString:[_session propertyForName:@"download"]];
                        url = [NSURL URLWithString:attachment[@"links"][@"self"] relativeToURL:url];
                        if (! [db executeUpdate:@"INSERT OR REPLACE INTO attachments"
                               "(solution, identifier, name, contentType, revision, link, status, state)"
                               "VALUES"
                               "(?, ?, ?, ?, ?, ?, ?, ?)",
                               solution,
                               identifier,
                               name,
                               attachment[@"content_type"],
                               @(newRevision),
                               url.absoluteString,
                               @(AIQSynchronizationStatusSynchronized),
                               @(AIQAttachmentStateUnavailable)]) {
                            AIQLogCError(1, @"Did fail to store attachment %@ for document %@: %@", name, identifier, [db lastError].localizedDescription);
                            handler(AIQSynchronizationResultFailed);
                            return;
                        }

                        if (oldRevision == 0l) {
                            [[self synchronizerForType:type] didCreateAttachment:name identifier:identifier type:type solution:solution];
                        } else {
                            [[self synchronizerForType:type] didUpdateAttachment:name identifier:identifier type:type solution:solution];
                        }
                    }
                }
            }
        }
        handler(AIQSynchronizationResultNewData);
    }];
}

- (void)synchronizeWithCompletionHandler:(void (^)(AIQSynchronizationResult))handler {
    [_uploadQueue waitUntilAllOperationsAreFinished];
    if ([_session propertyForName:@"download"]) {
        [self synchronouslyPull:handler];
    } else {
        [self synchronouslyHandshake:handler];
    }
}

- (BOOL)cancel:(NSError *__autoreleasing *)error {
        _shouldCancel = YES;
        
        if (_connection) {
            AIQLogCInfo(1, @"Cancelling ongoing synchronization");
            [_connection cancel];
            _connection = nil;
        }
        
        AIQLogCInfo(1, @"Cancelling attachment queues");
        [_downloadQueue cancelAllOperations];
        [_uploadQueue cancelAllOperations];
        
        [_downloadQueue waitUntilAllOperationsAreFinished];
        [_uploadQueue waitUntilAllOperationsAreFinished];
        
        AIQLogCInfo(1, @"Synchronization cancelled");
        
        return YES;
}

- (BOOL)isRunning {
    @synchronized(self) {
        return (_connection) || (_downloadQueue.operationCount != 0) || (_uploadQueue.operationCount != 0);
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _connection = nil;
    
    if (_delegate) {
        [_delegate synchronization:self didFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault userInfo:error.userInfo]];
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
    
    if (_shouldCancel) {
        return;
    }
    
    if (_statusCode == 401) {
        // session must be killed
        [self handleUnauthorized];
        return;
    }
    
    if (_statusCode == 410) {
        // session must be renegotiated
        [self handleGone];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @autoreleasepool {
            NSDictionary *json = [_data JSONObject];
            
            if (! json) {
                [_delegate synchronization:self didFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault message:@"Empty response from the backend"]];
            } else if ((json[@"error"]) || (_statusCode > 299)) {
                if (_delegate) {
                    NSString *message = json[@"error_description"];
                    if (! message) {
                        message = @"Invalid response from the backend";
                    }
                    [_delegate synchronization:self didFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault message:message]];
                }
            } else if (json[@"changes"]) {
                [self handlePull:json];
            } else if (json[@"results"]) {
                [self handlePush:json];
            } else {
                [self handleHandshake:json];
            }
        }
    });
}

#pragma mark - Private API

- (void)handshake {
    AIQLogCInfo(1, @"Handshaking");

    _shouldCancel = NO;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_session propertyForName:@"startdatasync"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_documentTimeout];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [_connection start];
}

- (void)pull {
    AIQLogCInfo(1, @"Pulling");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_session propertyForName:@"download"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_documentTimeout];
    request.HTTPMethod = @"GET";
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [_connection start];
}

- (void)push {
    AIQLogCInfo(1, @"Pushing");
    
    __block NSError *error = nil;
    
    NSMutableArray *docs = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data, revision, status, identifier, type, solution FROM documents "
                           "WHERE status != ? AND status != ?",
                           @(AIQSynchronizationStatusSynchronized), @(AIQSynchronizationStatusRejected)];
        if (! rs) {
            error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            AIQLogCError(1, @"Could not retrieve unsynchronized documents: %@", error.localizedDescription);
            return;
        }
        
        while ([rs next]) {
            if (_shouldCancel) {
                [rs close];
                return;
            }
            
            AIQSynchronizationStatus status = [rs intForColumnIndex:2];
            NSMutableDictionary *doc = [NSMutableDictionary dictionary];
            doc[kAIQDocumentId] = [rs stringForColumnIndex:3];
            doc[kAIQDocumentType] = [rs stringForColumnIndex:4];
            doc[@"_solution"] = [rs stringForColumnIndex:5];
            long long revision = [rs longLongIntForColumnIndex:1];
            if (revision != 0) {
                doc[kAIQDocumentRevision] = @(revision);
            }
            if (status == AIQSynchronizationStatusDeleted) {
                doc[@"_deleted"] = @YES;
            } else {
                NSUInteger protocolVersion = [[_session propertyForName:@"protocolVersion"] integerValue];
                NSDictionary *content = [[rs dataForColumnIndex:0] JSONObject];
                if (protocolVersion == 0) {
                    for (NSString *key in content) {
                        doc[key] = content[key];
                    }
                } else {
                    doc[@"_content"] = content;
                }
            }
            [docs addObject:doc];
        }
        [rs close];
    }];
    
    if (_shouldCancel) {
        return;
    }
    
    if (error) {
        if (_delegate) {
            [_delegate synchronization:self didFailWithError:error];
        }
        return;
    }
    
    if (docs.count == 0) {
        AIQLogCInfo(1, @"No documents to push");
        [self queueUnsynchronizedAttachments];
        if (_delegate) {
            [_delegate didSynchronize:self];
        }
        return;
    }
    
    AIQLogCInfo(1, @"Pushing %ld documents", (unsigned long)docs.count);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[_session propertyForName:@"upload"]]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_documentTimeout];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [[@{@"docs": docs} JSONData] gzippedDataWithCompressionLevel:1.0f];
    [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [_connection start];
}

- (void)handleHandshake:(NSDictionary *)json {
    AIQLogCInfo(1, @"Handshake successful");
    [self storeLinks:json[@"links"]];
    [self pull];
}

- (void)handlePull:(NSDictionary *)json {
    __block NSError *error = nil;
    NSArray *changes = json[@"changes"];
    
    [_downloadQueue setSuspended:YES];
    
    if (! [self queueUnavailableAttachments:&error]) {
        AIQLogCError(1, @"Failed to queue unavailable attachments: %@", error.localizedDescription);
        if (_delegate) {
            [_delegate synchronization:self didFailWithError:error];
        }
        return;
    }
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        AIQLogCInfo(1, @"Processing %lu changes", (unsigned long)changes.count);
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        for (NSDictionary *change in changes) {
            if (_shouldCancel) {
                return;
            }
            
            NSString *solution = change[@"_solution"];
            if (! solution) {
                solution = @"_global";
            }
            
            NSString *identifier = change[@"_id"];
            NSString *type = change[@"_type"];
            BOOL exists = [self documentWithId:identifier forSolution:solution existsInDatabase:db];
            BOOL deleted = [change[@"_deleted"] boolValue];
            
            if (deleted) {
                // TODO: workaround for backend bug
                if (! [type isEqualToString:@"_clientcontext"]) {
                    if (exists) {
                        if (! [self deleteDocumentWithId:identifier andType:type forSolution:solution fileManager:fileManager fromDatabase:db error:&error]) {
                            return;
                        }
                    }
                }
            } else {
                if (exists) {
                    if (! [self updateDocumentWithId:identifier andType:type forSolution:solution usingChange:change fileManager:fileManager inDatabase:db error:&error]) {
                        return;
                    }
                } else {
                    if (! [self insertDocumentWithId:identifier andType:type forSolution:solution usingChange:change intoDatabase:db error:&error]) {
                        return;
                    }
                }
                
                NSDictionary *attachments = change[@"_attachments"];
                if (! attachments) {
                    continue;
                }
                
                for (NSString *name in attachments.allKeys) {
                    if (_shouldCancel) {
                        return;
                    }
                    
                    NSDictionary *attachment = attachments[name];
                    long long newRevision = [attachment[@"_rev"] longLongValue];
                    long long oldRevision = [self revisionOfAttachmentWithName:name forDocumentWithId:identifier forSolution:solution inDatabase:db error:&error];
                    if (oldRevision == -1) {
                        AIQLogCError(1, @"Could not retrieve revision for document %@: %@", identifier, error.localizedDescription);
                        return;
                    } else if (newRevision == oldRevision) {
                        NSURL *url = [NSURL URLWithString:[_session propertyForName:@"download"]];
                        url = [NSURL URLWithString:attachment[@"links"][@"self"] relativeToURL:url];
                        AIQLogCInfo(1, @"Updating link for attachment %@ in document %@", name, identifier);
                        if (! [db executeUpdate:@"UPDATE attachments SET link = ? WHERE solution = ? AND identifier = ? AND name = ?", url.absoluteString, solution, identifier, name]) {
                            error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                            return;
                        }
                    } else if (newRevision > oldRevision) {
                        if (oldRevision == 0l) {
                            AIQLogCInfo(1, @"Attachment %@ in document %@ is new, adding to pool", name, identifier);
                        } else {
                            AIQLogCInfo(1, @"Attachment %@ in document %@ is newer, adding to pool", name, identifier);
                        }
                        NSURL *url = [NSURL URLWithString:[_session propertyForName:@"download"]];
                        url = [NSURL URLWithString:attachment[@"links"][@"self"] relativeToURL:url];
                        if (! [db executeUpdate:@"INSERT OR REPLACE INTO attachments"
                                                 "(solution, identifier, name, contentType, revision, link, status, state)"
                                                 "VALUES"
                                                 "(?, ?, ?, ?, ?, ?, ?, ?)",
                                                 solution,
                                                 identifier,
                                                 name,
                                                 attachment[@"content_type"],
                                                 @(newRevision),
                                                 url.absoluteString,
                                                 @(AIQSynchronizationStatusSynchronized),
                                                 @(AIQAttachmentStateUnavailable)]) {
                            error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                            return;
                        }
                        AIQOperation *operation = [DownloadOperation new];
                        operation.solution = solution;
                        operation.identifier = identifier;
                        operation.type = type;
                        operation.attachmentName = name;
                        operation.synchronization = self;
                        operation.timeout = _attachmentTimeout;
                        if ([type isEqualToString:@"_launchable"]) {
                            operation.queuePriority = NSOperationQueuePriorityVeryHigh;
                        } else if ([type hasPrefix:@"_"]) {
                            operation.queuePriority = NSOperationQueuePriorityHigh;
                        }
                        operation.qualityOfService = NSQualityOfServiceBackground;
                        //                        if ([_downloadQueue.operations containsObject:operation]) {
                        //                            for (AIQOperation *existing in _downloadQueue.operations) {
                        //                                if (([existing.identifier isEqualToString:identifier]) && ([existing.attachmentName isEqualToString:name])) {
                        //                                    [operation addDependency:existing];
                        //                                }
                        //                            }
                        //                        }
                        [_downloadQueue addOperation:operation];
                        
                        if (oldRevision == 0l) {
                            [[self synchronizerForType:type] didCreateAttachment:name identifier:identifier type:type solution:solution];
                        } else {
                            [[self synchronizerForType:type] didUpdateAttachment:name identifier:identifier type:type solution:solution];
                        }
                    }
                }
            }
        }
    }];
    
    if ((! _shouldCancel) && (error)) {
        if (_delegate) {
            [_delegate synchronization:self didFailWithError:error];
        }
        return;
    }
    
    [_downloadQueue setSuspended:NO];
    
    [self storeLinks:json[@"links"]];
    [self push];
}

- (long long)revisionOfAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier forSolution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    FMResultSet *rs = [db executeQuery:@"SELECT revision FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", solution, identifier, name];
    if (! rs) {
        *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        return -1;
    }
    long long result;
    if ([rs next]) {
        result = [rs longLongIntForColumnIndex:0];
    } else {
        result = 0;
    }
    [rs close];
    return result;
}

- (BOOL)documentWithId:(NSString *)identifier forSolution:(NSString *)solution existsInDatabase:(FMDatabase *)db {
    FMResultSet *rs = [db executeQuery:@"SELECT COUNT(identifier) FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        return NO;
    }
    BOOL result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
    [rs close];
    return result;
}

- (void)handlePush:(NSDictionary *)json {
    NSArray *results = json[@"results"];
    NSLog(@"%@", results);
    AIQLogCInfo(1, @"Processing %lu results", (unsigned long)results.count);
    
    __block NSError *error = nil;
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        for (NSDictionary *result in results) {
            if (_shouldCancel) {
                return;
            }
            
            NSString *identifier = result[kAIQDocumentId];
            NSString *solution = result[@"_solution"];
            if (! solution) {
                solution = @"_global";
            }
            
            NSDictionary *document = [self documentWithId:identifier forSolution:solution inDatabase:db error:&error];
            if (! document) {
                return;
            }
            NSString *type = document[kAIQDocumentType];
            
            if (result[@"_error"]) {
                NSUInteger statusCode = [result[@"_error"] integerValue];
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
                    
                    if (! [db executeUpdate:@"UPDATE documents SET status = ?, rejectionReason = ? WHERE solution = ? AND identifier = ?",
                           @(AIQSynchronizationStatusRejected), @(reason), solution, identifier]) {
                        error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                        AIQLogCError(1, @"Could not reject document %@: %@", identifier, error.localizedDescription);
                        return;
                    }
                    
                    [[self synchronizerForType:type] didRejectDocument:identifier type:type solution:solution reason:reason];
                } else {
                    AIQLogCWarn(1, @"Document %@ temporarily failed to synchronize: %lu", identifier, (unsigned long)statusCode);
                    [[self synchronizerForType:type] documentError:identifier type:type solution:solution errorCode:statusCode status:[document[kAIQDocumentStatus] intValue]];
                }
                
                continue;
            }
            
            if ([self isDocumentWriteOnlyWithId:identifier type:type]) {
                AIQLogCInfo(1, @"Synchronized document %@ is write only, deleting", identifier);
                if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
                    error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                    AIQLogCError(1, @"Could not delete write only document %@: %@", identifier, error.localizedDescription);
                    return;
                }
            } else {
                AIQSynchronizationStatus status = [document[kAIQDocumentStatus] intValue];
                
                if (status == AIQSynchronizationStatusDeleted) {
                    AIQLogCInfo(1, @"Document %@ was deleted locally, removing", identifier);
                    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
                        error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                        AIQLogCError(1, @"Could not delete document %@: %@", identifier, error.localizedDescription);
                        return;
                    }
                } else {
                    NSNumber *revision = result[@"_rev"];
                    AIQLogCInfo(1, @"Document %@ was updated locally, changing revision to %@", identifier, revision);
                    if (! [db executeUpdate:@"UPDATE documents SET status = ?, revision = ? WHERE solution = ? AND identifier = ?",
                           @(AIQSynchronizationStatusSynchronized), revision, solution, identifier]) {
                        error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                        AIQLogCError(1, @"Could not update revision of document %@: %@", identifier, error.localizedDescription);
                        return;
                    }
                }
            }
            
            [[self synchronizerForType:type] didSynchronizeDocument:identifier type:type solution:solution];
        }
    }];
    
    if (error) {
        if (_delegate) {
            [_delegate synchronization:self didFailWithError:error];
        }
    } else {
        [self storeLinks:json[@"links"]];
        
        [self queueUnsynchronizedAttachments];
        
        if (_delegate) {
            [_delegate didSynchronize:self];
        }
    }
}

- (void)storeLinks:(NSDictionary *)links {
    if (links[@"nextDownload"]) {
        [_session setProperty:links[@"nextDownload"] forName:@"download"];
    } else if (links[@"download"]) {
        [_session setProperty:links[@"download"] forName:@"download"];
    }
    if (links[@"nextUpload"]) {
        [_session setProperty:links[@"nextUpload"] forName:@"upload"];
    } else if (links[@"upload"]) {
        [_session setProperty:links[@"upload"] forName:@"upload"];
    }
    if (links[@"nextPending"]) {
        [_session setProperty:links[@"nextPending"] forName:@"pending"];
    } else if (links[@"pending"]) {
        [_session setProperty:links[@"pending"] forName:@"pending"];
    }
    if (links[@"nextAttachments"]) {
        [_session setProperty:links[@"nextAttachments"] forName:@"attachments"];
    } else if (links[@"attachments"]) {
        [_session setProperty:links[@"attachments"] forName:@"attachments"];
    }
    if (links[@"nextPush"]) {
        [_session setProperty:links[@"nextPush"] forName:@"push"];
    } else if (links[@"push"]) {
        [_session setProperty:links[@"push"] forName:@"push"];
    }
}

- (BOOL)insertDocumentWithId:(NSString *)identifier
                     andType:(NSString *)type
                 forSolution:(NSString *)solution
                 usingChange:(NSDictionary *)change
                intoDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    NSUInteger protocolVersion = [[_session propertyForName:@"protocolVersion"] integerValue];
    NSDictionary *content;
    if (protocolVersion == 0) {
        NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
        for (NSString *field in change) {
            if (! [field hasPrefix:@"_"]) {
                filtered[field] = change[field];
            }
        }
        content = filtered;
    } else {
        content = change[@"_content"];
    }
    
    NSError *localError = nil;
    if (! [db executeUpdate:@"INSERT OR REPLACE INTO documents"
                             "(solution, identifier, type, revision, status, launchable, data)"
                             "VALUES"
                             "(?, ?, ?, ?, ?, ?, ?)",
                             solution, identifier, type, change[@"_rev"], @(AIQSynchronizationStatusSynchronized), change[@"_launchable"], [content JSONData]]) {
        localError = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        AIQLogCError(1, @"Could not update document %@: %@", identifier, localError.localizedDescription);
        *error = localError;
        return NO;
    }
    
    [[self synchronizerForType:type] didCreateDocument:identifier type:type solution:solution];
    
    return YES;
}

- (BOOL)updateDocumentWithId:(NSString *)identifier
                     andType:(NSString *)type
                 forSolution:(NSString *)solution
                 usingChange:(NSDictionary *)change
                 fileManager:(NSFileManager *)fileManager
                  inDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    __block NSError *localError = nil;
    long long newRevision = [change[@"_rev"] integerValue];
    long long oldRevision = [self revisionOfDocumentWithId:identifier forSolution:solution inDatabase:db error:&localError];
    if (oldRevision == -1l) {
        AIQLogCError(1, @"Could not retrieve revision for document %@: %@", identifier, localError.localizedDescription);
        *error = localError;
        return NO;
    }
    
    if (newRevision <= oldRevision) {
        return YES;
    }
    
    FMResultSet *rs = [db executeQuery:@"SELECT name FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        localError = [db lastError];
        AIQLogCError(1, @"Could not retrieve removed attachments for document %@: %@", identifier, localError.localizedDescription);
        return NO;
    }
    
    NSDictionary *new = change[@"_attachments"];
    NSMutableArray *old = [NSMutableArray array];
    while ([rs next]) {
        NSString *name = [rs stringForColumnIndex:0];
        if ([new objectForKey:name]) {
            continue;
        }
        [old addObject:name];
    }
    [rs close];
    
    for (NSString *name in old) {
        AIQLogCInfo(1, @"Removing local copy of attachment %@ for document %@", name, identifier);
        
        if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", solution, identifier, name]) {
            localError = [db lastError];
            AIQLogCError(1, @"Could not delete attachment %@ for document %@: %@", name, identifier, localError.localizedDescription);
            return NO;
        }
        
        [[self synchronizerForType:type] didDeleteAttachment:name identifier:identifier type:type solution:solution];
        
        [fileManager removeItemAtPath:[[[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name] error:nil];
    }
    
    NSUInteger protocolVersion = [[_session propertyForName:@"protocolVersion"] integerValue];
    NSDictionary *content;
    if (protocolVersion == 0) {
        NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
        for (NSString *field in change) {
            if (! [field hasPrefix:@"_"]) {
                filtered[field] = change[field];
            }
        }
        content = filtered;
    } else {
        content = change[@"_content"];
    }
    
    if (! [db executeUpdate:@"UPDATE documents SET revision = ?, status = ?, launchable = ?, data = ? WHERE solution = ? AND identifier = ?",
           @(newRevision), @(AIQSynchronizationStatusSynchronized), change[@"_launchable"], [content JSONData], solution, identifier]) {
        localError = [db lastError];
        AIQLogCError(1, @"Could not update document %@: %@", identifier, localError.localizedDescription);
        return NO;
    }
    
    if (localError) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    [[self synchronizerForType:type] didUpdateDocument:identifier type:type solution:solution];
    
    return YES;
}

- (NSDictionary *)documentWithId:(NSString *)identifier forSolution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    FMResultSet *rs = [db executeQuery:@"SELECT type, status FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        return nil;
    }
    
    NSDictionary *result = nil;
    if ([rs next]) {
        result = @{kAIQDocumentType: [rs stringForColumnIndex:0], kAIQDocumentStatus: [rs objectForColumnIndex:1]};
    }
    [rs close];
    
    return result;
}

- (long long)revisionOfDocumentWithId:(NSString *)identifer forSolution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    FMResultSet *rs = [db executeQuery:@"SELECT revision FROM documents WHERE solution = ? AND identifier = ?", solution, identifer];
    if (! rs) {
        *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        return -1;
    }
    
    [rs next];
    
    long long result = [rs longLongIntForColumnIndex:0];
    [rs close];
    return result;
}

- (BOOL)deleteDocumentWithId:(NSString *)identifier
                     andType:(NSString *)type
                 forSolution:(NSString *)solution
                 fileManager:(NSFileManager *)fileManager
                fromDatabase:(FMDatabase *)db
                       error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    NSError *localError = nil;
    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
        localError = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        AIQLogCError(1, @"Could not delete document %@: %@", identifier, localError.localizedDescription);
        *error = localError;
        return NO;
    }
    
    if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier]) {
        localError = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        AIQLogCError(1, @"Could not delete attachments of document %@: %@", identifier, localError.localizedDescription);
        *error = localError;
        return NO;
    }
    
    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    if ([fileManager fileExistsAtPath:path]) {
        if (! [fileManager removeItemAtPath:path error:&localError]) {
            AIQLogCError(1, @"Could not remove attachment files for document %@: %@", identifier, localError.localizedDescription);
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
            return NO;
        }
    }
    
    [[self synchronizerForType:type] didDeleteDocument:identifier type:type solution:solution];
    
    return YES;
}

- (NSArray *)removedAttachmentsForDocumentWithId:(NSString *)identifier
                                     forSolution:(NSString *)solution
                                      inDatabase:(FMDatabase *)db
                          whereNewAttachmentsAre:(NSDictionary *)new
                                           error:(NSError *__autoreleasing *)error {
    FMResultSet *rs = [db executeQuery:@"SELECT name FROM attachments WHERE solution = ? AND identifier = ?", solution, identifier];
    if (! rs) {
        *error = [db lastError];
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next]) {
        NSString *name = [rs stringForColumnIndex:0];
        if (! [new objectForKey:name]) {
            [result addObject:name];
        }
    }
    [rs close];
    return result;
}

- (BOOL)isDocumentWriteOnlyWithId:(NSString *)identifier type:(NSString *)type {
    // TODO: should check with the backend, hardcoding until the protocol is ready
    return [type isEqualToString:@"_backendmessagestatus"];
}

- (BOOL)queueUnavailableAttachments:(NSError *__autoreleasing *)error {
    __block NSError *localError = nil;
    
    AIQLogCInfo(1, @"Queuing unavailable attachments");
    
    [_downloadQueue setSuspended:YES];
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT d.identifier, d.type, a.name, d.solution FROM attachments a, documents d "
                           "WHERE a.solution = d.solution AND a.identifier = d.identifier AND a.state = ?",
                           @(AIQAttachmentStateUnavailable)];
        if (! rs) {
            localError = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            return;
        }
        
        while ([rs next]) {
            if (_shouldCancel) {
                [rs close];
                return;
            }
            
            NSString *identifier = [rs stringForColumnIndex:0];
            NSString *type = [rs stringForColumnIndex:1];
            
            AIQOperation *operation = [DownloadOperation new];
            operation.solution = [rs stringForColumnIndex:3];
            operation.identifier = identifier;
            operation.type = type;
            operation.attachmentName = [rs stringForColumnIndex:2];
            operation.synchronization = self;
            operation.timeout = _attachmentTimeout;
            if ([_downloadQueue.operations containsObject:operation]) {
                AIQLogCInfo(1, @"Attachment %@ for document %@ already in queue %lu", operation.attachmentName, identifier, (unsigned long)_downloadQueue.operationCount);
                continue;
            }
            if ([type isEqualToString:@"_launchable"]) {
                operation.queuePriority = NSOperationQueuePriorityVeryHigh;
            } else if ([type hasPrefix:@"_"]) {
                operation.queuePriority = NSOperationQueuePriorityHigh;
            }
            operation.qualityOfService = NSQualityOfServiceBackground;
            [_downloadQueue addOperation:operation];
        }
        [rs close];
    }];
    
    if (localError) {
        *error = localError;
        return NO;
    }
    
    [_downloadQueue setSuspended:NO];
    
    return YES;
}

- (void)queueUnsynchronizedAttachments {
    __block NSError *error = nil;
    
    [_uploadQueue setSuspended:YES];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT d.identifier, d.type, a.name, a.status, d.solution FROM attachments a, documents d "
                           "WHERE a.solution = d.solution AND a.identifier = d.identifier AND a.status != ? AND a.status != ? AND d.status != ?",
                           @(AIQSynchronizationStatusSynchronized), @(AIQSynchronizationStatusRejected), @(AIQSynchronizationStatusRejected)];
        if (! rs) {
            error = [db lastError];
            return;
        }
        
        while ([rs next]) {
            if (_shouldCancel) {
                [rs close];
                return;
            }
            
            AIQSynchronizationStatus status = [rs intForColumnIndex:3];
            AIQOperation *operation = (status == AIQSynchronizationStatusDeleted) ? [DeleteOperation new] : [UploadOperation new];
            operation.solution = [rs stringForColumnIndex:4];
            operation.identifier = [rs stringForColumnIndex:0];
            operation.type = [rs stringForColumnIndex:1];
            operation.attachmentName = [rs stringForColumnIndex:2];
            operation.synchronization = self;
            operation.timeout = _attachmentTimeout;
            operation.queuePriority = NSOperationQueuePriorityLow;
            operation.qualityOfService = NSQualityOfServiceBackground;
            [_uploadQueue addOperation:operation];
        }
        [rs close];
    }];
    
    if (error) {
        AIQLogCError(1, @"Could not retrieve unsynchronized attachments: %@", error.localizedDescription);
        if (_delegate) {
            [_delegate synchronization:self didFailWithError:error];
        }
    } else {
        [_uploadQueue setSuspended:NO];
    }
}

- (void)handleUnauthorized {
    if (_shouldCancel) {
        return;
    }
    
    AIQLogCInfo(1, @"Login session has expired, cancelling and logging out");
    NSError *error = nil;
    if (! [self cancel:&error]) {
        AIQLogCError(1, @"Error cancelling synchronization: %@", error.localizedDescription);
        abort();
    }
    
    if (_synchronizers) {
        [_synchronizers.allValues makeObjectsPerformSelector:@selector(close)];
    }
    
    if (! [_session close:&error]) {
        AIQLogCError(1, @"Error closing session: %@", error.localizedDescription);
        abort();
    }
}

- (void)handleGone {
    if (_shouldCancel) {
        return;
    }
    
    AIQLogCInfo(1, @"Synchronization session has expired, restarting synchronization session");
    NSError *error = nil;
    if (! [self cancel:&error]) {
        AIQLogCError(1, @"Error cancelling synchronization: %@", error.localizedDescription);
        abort();
    }
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"DELETE FROM documents WHERE status = ?", @(AIQSynchronizationStatusSynchronized)]) {
            AIQLogCError(1, @"Failed to clean synchronized data: %@", [db lastError].localizedDescription);
            abort();
        }
        if (! [db executeUpdate:@"UPDATE attachments SET link = NULL WHERE status = ?", @(AIQSynchronizationStatusSynchronized)]) {
            AIQLogCError(1, @"Failed to clean synchronized data: %@", [db lastError].localizedDescription);
            abort();
        }
    }];
    
    [_session setValue:@NO forKey:@"registeredForPushNotifications"];
    
    [self handshake];
}

- (void)registerSynchronizer:(id<AIQSynchronizer>)synchronizer forType:(NSString *)type {
    if (! _synchronizers) {
        _synchronizers = [NSMutableDictionary dictionaryWithObject:synchronizer forKey:type];
    } else {
        [_synchronizers setObject:synchronizer forKey:type];
    }
}

- (id<AIQSynchronizer>)synchronizerForType:(NSString *)type {
    if (! _synchronizers) {
        return self;
    }
    id<AIQSynchronizer> synchronizer = _synchronizers[type];
    if (! synchronizer) {
        return self;
    }
    
    return synchronizer;
}

#pragma mark - AIQSynchronizer

- (void)didCreateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidCreateDocumentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQDocumentTypeUserInfoKey: type,
                                                      AIQSolutionUserInfoKey: solution}));
}

- (void)didUpdateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidUpdateDocumentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQDocumentTypeUserInfoKey: type,
                                                      AIQSolutionUserInfoKey: solution}));
}

- (void)didDeleteDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidDeleteDocumentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQDocumentTypeUserInfoKey: type,
                                                      AIQSolutionUserInfoKey: solution}));
}

- (void)didSynchronizeDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidSynchronizeDocumentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                           AIQDocumentTypeUserInfoKey: type,
                                                           AIQSolutionUserInfoKey: solution}));
}

- (void)didRejectDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    NOTIFY(AIQDidRejectDocumentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQDocumentTypeUserInfoKey: type,
                                                      AIQSolutionUserInfoKey: solution,
                                                      AIQRejectionReasonUserInfoKey: @(reason)}));
}

- (void)documentError:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status {
    NOTIFY(AIQDocumentErrorNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                  AIQDocumentTypeUserInfoKey: type,
                                                  AIQSynchronizationErrorCodeKey: @(code),
                                                  AIQSynchronizationStatusUserInfoKey: @(status),
                                                  AIQSolutionUserInfoKey: solution}));
}

- (void)didCreateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidCreateAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                        AIQDocumentTypeUserInfoKey: type,
                                                        AIQAttachmentNameUserInfoKey: name,
                                                        AIQSolutionUserInfoKey: solution}));
}

- (void)didUpdateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidUpdateAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                        AIQDocumentTypeUserInfoKey: type,
                                                        AIQAttachmentNameUserInfoKey: name,
                                                        AIQSolutionUserInfoKey: solution}));
}

- (void)didDeleteAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidDeleteAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                        AIQDocumentTypeUserInfoKey: type,
                                                        AIQAttachmentNameUserInfoKey: name,
                                                        AIQSolutionUserInfoKey: solution}));
}

- (void)didSynchronizeAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQDidSynchronizeAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                             AIQDocumentTypeUserInfoKey: type,
                                                             AIQAttachmentNameUserInfoKey: name,
                                                             AIQSolutionUserInfoKey: solution}));
}

- (void)didRejectAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    NOTIFY(AIQDidRejectAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                        AIQDocumentTypeUserInfoKey: type,
                                                        AIQAttachmentNameUserInfoKey: name,
                                                        AIQSolutionUserInfoKey: solution}));
}

- (void)attachmentError:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status {
    NOTIFY(AIQAttachmentErrorNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                    AIQDocumentTypeUserInfoKey: type,
                                                    AIQAttachmentNameUserInfoKey: name,
                                                    AIQSolutionUserInfoKey: solution}));
}

- (void)willDownloadAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQWillDownloadAttachmentNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                           AIQDocumentTypeUserInfoKey: type,
                                                           AIQAttachmentNameUserInfoKey: name,
                                                           AIQSolutionUserInfoKey: solution}));
}

- (void)attachmentDidBecomeAvailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQAttachmentDidBecomeAvailableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                 AIQDocumentTypeUserInfoKey: type,
                                                                 AIQAttachmentNameUserInfoKey: name,
                                                                 AIQSolutionUserInfoKey: solution}));
}

- (void)attachmentDidBecomeUnavailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQAttachmentDidBecomeUnavailableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                   AIQDocumentTypeUserInfoKey: type,
                                                                   AIQAttachmentNameUserInfoKey: name,
                                                                   AIQSolutionUserInfoKey: solution}));
}

- (void)attachmentDidFail:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    NOTIFY(AIQAttachmentDidFailNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQDocumentTypeUserInfoKey: type,
                                                      AIQAttachmentNameUserInfoKey: name,
                                                      AIQSolutionUserInfoKey: solution}));
}

- (void)attachmentDidProgress:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution progress:(float)progress {
    
}

- (void)close {
    AIQLogCInfo(1, @"Closing synchronization receivers");
    if (_synchronizers) {
        [_synchronizers.allValues makeObjectsPerformSelector:@selector(close)];
    }
}

@end
