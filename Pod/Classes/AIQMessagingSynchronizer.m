#import <FMDB/FMDB.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "AIQContext.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQLog.h"
#import "AIQMessaging.h"
#import "AIQMessagingSynchronizer.h"
#import "AIQScheduler.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "AIQSynchronizationManager.h"
#import "Reachability.h"
#import "SendMessageOperation.h"
#import "common.h"

@interface AIQMessagingSynchronizer () {
    AIQSession *_session;
    FMDatabasePool *_pool;
    NSString *_basePath;
    BOOL _hasMessages;
    NSTimeInterval _previousActionDate;
    NSTimeInterval _nextActionDate;
    NSTimer *_timer;
    NSOperationQueue *_operationQueue;
    dispatch_queue_t _serialQueue;
    AIQContext *_context;
    Reachability *_reachability;
    NetworkStatus _networkStatus;
}

@end

@implementation AIQMessagingSynchronizer

- (instancetype)initForSession:(AIQSession *)session {
    self = [super init];
    if (self) {
        _basePath = [session valueForKey:@"basePath"];
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
        _nextActionDate = [[NSDate distantFuture] timeIntervalSince1970];
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;
        _session = session;
        _context = [session context:nil];
        _serialQueue = dispatch_queue_create("com.appearnetworks.aiq.AIQMessagingSynchronizer", DISPATCH_QUEUE_SERIAL);
        
        _reachability = [Reachability reachabilityForInternetConnection];
        __weak typeof(self) weakSelf = self;
        _reachability.reachableBlock = ^(Reachability *reachability) {
            NetworkStatus networkStatus = [reachability currentReachabilityStatus];
            if (_networkStatus == NotReachable) {
                AIQLogCInfo(1, @"Network available, pushing client originated messages");
                [weakSelf pushMessages];
            }
            _networkStatus = networkStatus;
        };
        _networkStatus = [_reachability currentReachabilityStatus];
        [_reachability startNotifier];
        
        LISTEN(self, @selector(synchronizationComplete:), AIQSynchronizationCompleteEvent);
#if TARGET_OS_IPHONE
        LISTEN(self, @selector(applicationDidEnterBackground:), UIApplicationDidEnterBackgroundNotification);
        LISTEN(self, @selector(applicationWillEnterForeground:), UIApplicationWillEnterForegroundNotification);
#endif
        
        _previousActionDate = [NSDate date].timeIntervalSince1970;
        [self scheduleNextNotification];
    }
    return self;
}

- (void)didCreateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    dispatch_async(_serialQueue, ^{
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE solution = ? AND identifier = ?", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Message document %@ not found", identifier);
                return;
            }
            
            NSMutableDictionary *message = [[rs dataForColumnIndex:0] JSONObject];
            [rs close];
            
            NSString *messageType = message[kAIQMessageType];
            NSTimeInterval timeToLive = [message[kAIQMessageTimeToLive] doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval activeFrom = [message[kAIQMessageActiveFrom] doubleValue] / 1000.0f;
            
            if (activeFrom + timeToLive <= now) {
                // message has already expired
                AIQLogCInfo(1, @"Message %@ (%@) is already expired, removing", identifier, messageType);
                [self deleteMessageDocumentWithId:identifier solution:solution inDatabase:db];
                return;
            }
            
            AIQLogCInfo(1, @"Creating message %@ (%@)", identifier, messageType);
            if (! [db executeUpdate:@"INSERT OR REPLACE INTO somessages (solution, identifier, type, revision, created, activeFrom, timeToLive, read)"
                   "VALUES (?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT read FROM somessages WHERE identifier = ?), 0))",
                   solution, identifier, messageType, message[@"revision"], message[kAIQMessageCreated], message[kAIQMessageActiveFrom], @(timeToLive), @NO]) {
                AIQLogCError(1, @"Error storing message %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            _hasMessages = YES;
            message[kAIQDocumentId] = identifier;
            message[@"solution"] = solution;
            
            if (! _hasMessages) {
                _previousActionDate = now;
            }
            
            if ((activeFrom <= now) && (activeFrom + timeToLive >= now)) {
                // message is active, check expiration date
                AIQLogCInfo(1, @"Message %@ (%@) is already active", identifier, messageType);
                
                // message is active
                NOTIFY(AIQDidReceiveMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                  AIQMessageTypeUserInfoKey: messageType,
                                                                  AIQSolutionUserInfoKey: solution}));
                if (activeFrom + timeToLive < _nextActionDate) {
                    _nextActionDate = activeFrom + timeToLive;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:_nextActionDate];
                    AIQLogCInfo(1, @"Message %@ (%@) scheduled for expiration on %@", identifier, messageType, date);
                    [self runTimerAt:_nextActionDate];
                } else {
                    AIQLogCInfo(1, @"Message %@ (%@) not scheduled for expiration yet", identifier, messageType);
                }
            } else if (activeFrom >= now) {
                // message is pending activation
                if (activeFrom < _nextActionDate) {
                    _nextActionDate = activeFrom;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:_nextActionDate];
                    AIQLogCInfo(1, @"Message %@ (%@) scheduled for activation on %@", identifier, messageType, date);
                    [self runTimerAt:_nextActionDate];
                } else {
                    AIQLogCInfo(1, @"Message %@ (%@) not scheduled for activation yet", identifier, messageType);
                }
            }
            
            if ([messageType isEqualToString:@"_comessageresponse"]) {
                [self handleCOMessageResponse:message[kAIQMessagePayload] forMessageWithId:identifier solution:solution inDatabase:db];
            }
        }];
    });
}

- (void)didUpdateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    dispatch_async(_serialQueue, ^{
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT d.data, m.activeFrom / 1000, m.timeToLive, m.revision FROM documents d, somessages m "
                               "WHERE d.solution = ? AND d.identifier = ? AND d.solution = m.solution AND d.identifier = m.identifier",
                               solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Message document %@ not found", identifier);
                return;
            }
            
            NSMutableDictionary *newMessage = [[rs dataForColumnIndex:0] JSONObject];
            NSTimeInterval oldActiveFrom = [rs doubleForColumnIndex:1];
            NSTimeInterval oldTimeToLive = [rs doubleForColumnIndex:2];
            long long oldRevision = [rs longLongIntForColumnIndex:3];
            [rs close];
            
            NSTimeInterval newActiveFrom = [newMessage[kAIQMessageActiveFrom] doubleValue] / 1000.0f;
            NSTimeInterval newTimeToLive = [newMessage[kAIQMessageTimeToLive] doubleValue];
            NSString *messageType = newMessage[kAIQMessageType];
            
            long long newRevision = [newMessage[@"revision"] longLongValue];
            BOOL payloadUpdated = (newRevision > oldRevision);
            AIQLogCInfo(1, @"Updating message %@ (%@)", identifier, messageType);
            if (! [db executeUpdate:@"INSERT OR REPLACE INTO somessages (solution, identifier, type, revision, created, activeFrom, timeToLive, read)"
                   "VALUES (?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT read FROM somessages WHERE identifier = ?), 0))",
                   solution, identifier, messageType, newMessage[@"revision"], newMessage[kAIQMessageCreated], newMessage[kAIQMessageActiveFrom], @(newTimeToLive), @(! payloadUpdated)]) {
                AIQLogCError(1, @"Error updating message %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            newMessage[@"solution"] = solution;
            
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            BOOL wasActive = ((oldActiveFrom <= now) && (oldActiveFrom + oldTimeToLive >= now));
            BOOL isActive = ((newActiveFrom <= now) && (newActiveFrom + newTimeToLive >= now));
            if (! _hasMessages) {
                _previousActionDate = now;
            }
            
            if ((wasActive) && (! isActive)) {
                AIQLogCInfo(1, @"Updated message %@ (%@) becomes inactive", identifier, messageType);
                if (newActiveFrom < _nextActionDate) {
                    _nextActionDate = newActiveFrom;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:_nextActionDate];
                    AIQLogCInfo(1, @"Message %@ (%@) scheduled for activation on %@", identifier, messageType, date);
                    [self runTimerAt:_nextActionDate];
                }
                
                if ([self deleteMessageDocumentWithId:identifier solution:solution inDatabase:db]) {
                    NOTIFY(AIQDidExpireMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                     AIQMessageTypeUserInfoKey: messageType,
                                                                     AIQSolutionUserInfoKey: solution}));
                }
            } else if ((! wasActive) && (isActive)) {
                AIQLogCInfo(1, @"Updated message %@ (%@) becomes active", identifier, messageType);
                NOTIFY(AIQDidReceiveMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                  AIQMessageTypeUserInfoKey: messageType,
                                                                  AIQSolutionUserInfoKey: solution}));
                if (newActiveFrom + newTimeToLive < _nextActionDate) {
                    _nextActionDate = newActiveFrom + newTimeToLive;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:_nextActionDate];
                    AIQLogCInfo(1, @"Message %@ (%@) scheduled for expiration on %@", identifier, messageType, date);
                    [self runTimerAt:_nextActionDate];
                }
            } else {
                AIQLogCInfo(1, @"Validity did not change for message %@ (%@)", identifier, messageType);
            }
            
            if (payloadUpdated) {
                AIQLogCInfo(1, @"Payload updated for message %@ (%@)", identifier, messageType);
                NOTIFY(AIQDidUpdateMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                 AIQMessageTypeUserInfoKey: messageType,
                                                                 AIQSolutionUserInfoKey: solution}));
            }
        }];
    });
}

- (void)didDeleteDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    dispatch_async(_serialQueue, ^{
        AIQLogCInfo(1, @"Deleting message %@", identifier);
        
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT type FROM somessages WHERE solution = ? AND identifier = ?", solution, identifier];
            if (! rs) {
                AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            if (! [rs next]) {
                [rs close];
                AIQLogCError(1, @"Message document %@ not found", identifier);
                return;
            }
            
            NSString *messageType = [rs stringForColumnIndex:0];
            [rs close];
            
            NSError *error = nil;
            if ([messageType isEqualToString:@"_comessageresponse"]) {
                if (! [self expireCOMessageForResponseId:identifier solution:solution inDatabase:db error:&error]) {
                    AIQLogCWarn(1, @"Failed to expire client originated message %@: %@", identifier, error.localizedDescription);
                }
            }
            
            if (! [db executeUpdate:@"DELETE FROM somessages WHERE solution = ? AND identifier = ?", solution, identifier]) {
                AIQLogCError(1, @"Error deleting message %@: %@", identifier, [db lastError].localizedDescription);
                return;
            }
            
            NOTIFY(AIQDidExpireMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                             AIQMessageTypeUserInfoKey: messageType,
                                                             AIQSolutionUserInfoKey: solution}));
            
            [self scheduleNextNotification];
        }];
    });
}

- (void)didSynchronizeDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)didRejectDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason {
    
}

- (void)documentError:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status {
    
}

- (void)didCreateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
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
    
}

- (void)attachmentDidBecomeAvailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type FROM somessages WHERE solution = ? AND identifier = ?", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            AIQLogCError(1, @"Message document %@ not found", identifier);
            return;
        }
        
        NSString *messageType = [rs stringForColumnIndex:0];
        [rs close];
        
        NOTIFY(AIQMessageAttachmentDidBecomeAvailableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                            AIQMessageTypeUserInfoKey: messageType,
                                                                            AIQAttachmentNameUserInfoKey: name,
                                                                            AIQSolutionUserInfoKey: solution}));
    }];
}

- (void)attachmentDidBecomeUnavailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type FROM somessages WHERE solution = ? AND identifier = ?", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            AIQLogCError(1, @"Message document %@ not found", identifier);
            return;
        }
        
        NSString *messageType = [rs stringForColumnIndex:0];
        [rs close];
        
        NOTIFY(AIQMessageAttachmentDidBecomeUnavailableNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                                              AIQMessageTypeUserInfoKey: messageType,
                                                                              AIQAttachmentNameUserInfoKey: name,
                                                                              AIQSolutionUserInfoKey: solution}));
    }];
}

- (void)attachmentDidFail:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type FROM somessages WHERE solution = ? AND identifier = ?", solution, identifier];
        if (! rs) {
            AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            AIQLogCError(1, @"Message document %@ not found", identifier);
            return;
        }
        
        NSString *messageType = [rs stringForColumnIndex:0];
        [rs close];
        
        NOTIFY(AIQMessageAttachmentDidFailEvent, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                          AIQMessageTypeUserInfoKey: messageType,
                                                          AIQAttachmentNameUserInfoKey: name,
                                                          AIQSolutionUserInfoKey: solution}));
    }];
}

- (void)attachmentDidProgress:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution progress:(float)progress {
    
}

- (void)close {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    if (_reachability) {
        [_reachability stopNotifier];
        _reachability = nil;
    }
}

- (void)scheduleNextNotification {
    if (! _hasMessages) {
        AIQLogCInfo(1, @"No messages to schedule");
        return;
    }
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT CASE WHEN activeFrom / 1000 > ? THEN activeFrom / 1000 ELSE activeFrom / 1000 + timeToLive END AS date "
                           "FROM somessages "
                           "WHERE date > ? "
                           "ORDER BY date ASC LIMIT 1",
                           @(_previousActionDate),
                           @(_previousActionDate)];
        if (! rs) {
            AIQLogCError(1, @"Did fail to schedule next message: %@", [db lastError].localizedDescription);
            return;
        }
        
        if (! [rs next]) {
            AIQLogCInfo(1, @"No messages to schedule");
            [rs close];
            _hasMessages = NO;
            _nextActionDate = [[NSDate distantFuture] timeIntervalSince1970];
            return;
        }
        
        _nextActionDate = [rs doubleForColumnIndex:0];
        [rs close];
        
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:_nextActionDate];
        AIQLogCInfo(1, @"Next message event scheduled for %@", date);
        [self runTimerAt:_nextActionDate];
    }];
}

- (void)didFireMessageEvent {
    dispatch_async(_serialQueue, ^{
        [_pool inDatabase:^(FMDatabase *db) {
            NSTimeInterval now = [NSDate date].timeIntervalSince1970;
            FMResultSet *rs = [db executeQuery:@"SELECT "
                               "solution,"
                               "identifier,"
                               "type,"
                               "CASE WHEN activeFrom / 1000 = ? THEN activeFrom / 1000 ELSE activeFrom / 1000 + timeToLive END AS date,"
                               "CASE WHEN activeFrom / 1000 = ? THEN 0 ELSE 1 END "
                               "FROM somessages "
                               "WHERE date = ? "
                               "ORDER BY date ASC",
                               @(_nextActionDate),
                               @(_nextActionDate),
                               @(_nextActionDate)];
            if (! rs) {
                AIQLogCError(1, @"Did fail to schedule next message: %@", [db lastError].localizedDescription);
                return;
            }
            
            while ([rs next]) {
                NSString *solution = [rs stringForColumnIndex:0];
                NSString *identifier = [rs stringForColumnIndex:1];
                NSString *type = [rs stringForColumnIndex:2];
                BOOL active = [rs boolForColumnIndex:4];
                if (active) {
                    [self didExpireMessageWithId:identifier type:type inSolution:solution];
                } else {
                    [self didActivateMessageWithId:identifier type:type inSolution:solution];
                }
            }
            [rs close];
            
            _previousActionDate = now;
            [self scheduleNextNotification];
        }];
    });
}

- (void)didActivateMessageWithId:(NSString *)identifier type:(NSString *)type inSolution:(NSString *)solution {
    AIQLogCInfo(1, @"Message %@ (%@) activated", identifier, type);
    NOTIFY(AIQDidReceiveMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                      AIQMessageTypeUserInfoKey: type,
                                                      AIQSolutionUserInfoKey: solution}));
}

- (void)didExpireMessageWithId:(NSString *)identifier type:(NSString *)type inSolution:(NSString *)solution {
    __block NSError *error = nil;
    AIQLogCInfo(1, @"Message %@ (%@) expired", identifier, type);
    
    if ([type isEqualToString:@"_comessageresponse"]) {
        [_pool inDatabase:^(FMDatabase *db) {
            if (! [self expireCOMessageForResponseId:identifier solution:solution inDatabase:db error:&error]) {
                AIQLogCWarn(1, @"Failed to expire client originated message %@: %@", identifier, error.localizedDescription);
            }
        }];
    }
    
    if ([self deleteMessageWithId:identifier solution:solution]) {
        NOTIFY(AIQDidExpireMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier,
                                                         AIQMessageTypeUserInfoKey: type,
                                                         AIQSolutionUserInfoKey: solution}));
    }
}

- (void)pushMessages {
    AIQLogCInfo(1, @"Pushing client originated messages");
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT solution, identifier FROM comessages WHERE state = ? ORDER BY orderId ASC", @(AIQMessageStateQueued)];
        if (! rs) {
            AIQLogCError(1, @"Could not retrieve queued messages: %@", [db lastError].localizedDescription);
            return;
        }
        
        [_operationQueue setSuspended:YES];
        
        while ([rs next]) {
            NSString *identifier = [rs stringForColumnIndex:1];
            
            SendMessageOperation *operation = [SendMessageOperation new];
            operation.solution = [rs stringForColumnIndex:0];
            operation.identifier = identifier;
            operation.synchronizer = self;
            operation.thread = [NSThread mainThread];
            if ([_operationQueue.operations containsObject:operation]) {
                AIQLogCInfo(1, @"Message %@ already in the upload queue", identifier);
                continue;
            }
            AIQLogCInfo(1, @"Adding message %@ to the upload queue", identifier);
            operation.timeout = 60.0f;
            [_operationQueue addOperation:operation];
        }
        [rs close];
        
        [_operationQueue setSuspended:NO];
    }];
}

- (void)handleUnauthorized {
    AIQLogCInfo(1, @"Login session has expired, cancelling and logging out");
    
    [_operationQueue cancelAllOperations];
    
    _pool = nil;
    
    NSError *error = nil;
    
    if (! [_session close:&error]) {
        AIQLogCError(1, @"Error closing session: %@", error.localizedDescription);
        abort();
    }
}

- (void)handleCOMessageResponse:(NSDictionary *)response forMessageWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db {
    NSString *messageId = response[@"messageId"];
    NSString *payload = nil;
    
    if (response[@"payload"]) {
        payload = [response[@"payload"] JSONString];
    }
    AIQMessageState state;
    NSString *event;
    if ([response[@"success"] boolValue]) {
        AIQLogCInfo(1, @"Message %@ has been delivered", messageId);
        state = AIQMessageStateDelivered;
        event = AIQDidDeliverMessageNotification;
    } else {
        AIQLogCInfo(1, @"Message %@ has failed", messageId);
        state = AIQMessageStateFailed;
        event = AIQDidFailMessageNotification;
    }
    
    FMResultSet *rs = [db executeQuery:@"SELECT destination FROM comessages WHERE solution = ? AND identifier = ?", solution, messageId];
    if (! rs) {
        AIQLogCError(1, @"Did fail to retrieve message document %@: %@", identifier, [db lastError].localizedDescription);
        return;
    }
    
    if (! [rs next]) {
        [rs close];
        AIQLogCError(1, @"Message document %@ does not exsit", identifier);
        return;
    }
    
    NSString *destination = [rs stringForColumnIndex:0];
    [rs close];
    
    if (! [db executeUpdate:@"UPDATE comessages SET state = ?, response = ?, responseId = ? WHERE solution = ? AND identifier = ?",
           @(state), payload, identifier, solution, messageId]) {
        AIQLogCError(1, @"Did fail to update state of message %@: %@", identifier, [db lastError].localizedDescription);
        return;
    }
    
    NOTIFY(event, self, (@{AIQDocumentIdUserInfoKey: messageId, AIQMessageDestinationUserInfoKey: destination, AIQSolutionUserInfoKey: solution}));
}

- (BOOL)deleteMessageDocumentWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db {
    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
        AIQLogCError(1, @"Did fail to delete message document %@: %@", identifier, [db lastError].localizedDescription);
        return NO;
    }
    
    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path]) {
        [fileManager removeItemAtPath:path error:nil];
    }
    
    return YES;
}

- (BOOL)expireCOMessageForResponseId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    AIQLogCInfo(1, @"Message %@ has expired and will be deleted", identifier);
    
    if (! [db executeUpdate:@"DELETE FROM coattachments WHERE solution = ? AND identifier IN (SELECT identifier FROM comessages WHERE solution = ? AND responseId = ?)",
           solution, solution, identifier]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"DELETE FROM comessages WHERE solution = ? AND responseId = ?", solution, identifier]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)deleteMessageWithId:(NSString *)identifier solution:(NSString *)solution {
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"DELETE FROM somessages WHERE solution = ? AND identifier = ? "
               "AND DATETIME(activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
               "AND DATETIME(activeFrom / 1000 + timeToLive, 'unixepoch') >= DATETIME('now')",
               solution, identifier]) {
            AIQLogCError(1, @"Did fail to delete message %@: %@", identifier, [db lastError].localizedDescription);
            return;
        }
        
        if ([db changes] != 1) {
            AIQLogCError(1, @"Message %@ not found", identifier);
            return;
        }
        
        result = [self deleteMessageDocumentWithId:identifier solution:solution inDatabase:db];
    }];
    
    return result;
}

- (void)synchronizationComplete:(NSNotification *)notification {
    [self pushMessages];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self pushMessages];
}

- (BOOL)expireCOMessageForResponseId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db {
    AIQLogCInfo(1, @"Message %@ has expired and will be deleted", identifier);
    
    if (! [db executeUpdate:@"DELETE FROM coattachments WHERE solution = ? AND identifier IN (SELECT identifier FROM comessages WHERE solution = ? AND responseId = ?)",
           solution, solution]) {
        AIQLogCError(1, @"Did fail to delete attachments for message with response %@: %@", identifier, [db lastError].localizedDescription);
        return NO;
    }
    
    if (! [db executeUpdate:@"DELETE FROM comessages WHERE solution = ? AND responseId = ?", solution, identifier]) {
        AIQLogCError(1, @"Did fail to delete message with response %@: %@", identifier, [db lastError].localizedDescription);
        return NO;
    }
    
    return YES;
}

- (void)runTimerAt:(NSTimeInterval)time {
    if (_timer) {
        [_timer invalidate];
    }
    
    _timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSince1970:time]
                                      interval:0.0f
                                        target:self
                                      selector:@selector(didFireMessageEvent)
                                      userInfo:nil
                                       repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self scheduleNextNotification];
}

@end
