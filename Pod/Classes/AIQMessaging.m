#import <FMDB/FMDB.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    #import <AssetsLibrary/AssetsLibrary.h>
#endif

#import "AIQContext.h"
#import "AIQError.h"
#import "AIQLog.h"
#import "AIQMessaging.h"
#import "AIQMessagingSynchronizer.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "AIQSynchronizer.h"
#import "AIQJSON.h"
#import "common.h"
#import "NSDictionary+Helpers.h"

NSString *const kAIQMessageType = @"type";
NSString *const kAIQMessageDestination = @"destination";
NSString *const kAIQMessageState = @"state";
NSString *const kAIQMessageLaunchable = @"_launchable";
NSString *const kAIQMessageBody = @"body";
NSString *const kAIQMessageCreated = @"created";
NSString *const kAIQMessageActiveFrom = @"activeFrom";
NSString *const kAIQMessageTimeToLive = @"timeToLive";
NSString *const kAIQMessageRead = @"read";
NSString *const kAIQMessageUrgent = @"urgent";
NSString *const kAIQMessageRelevant = @"relevant";
NSString *const kAIQMessagePayload = @"payload";
NSString *const kAIQMessageText = @"message";
NSString *const kAIQMessageSound = @"sound";
NSString *const kAIQMessageVibrate = @"vibration";

NSString *const AIQDidReceiveMessageNotification = @"AIQDidReceiveMessageNotification";
NSString *const AIQDidUpdateMessageNotification = @"AIQDidUpdateMessageNotification";
NSString *const AIQDidExpireMessageNotification = @"AIQDidExpireMessageNotification";
NSString *const AIQDidReadMessageNotification = @"AIQDidReadMessageNotification";

NSString *const AIQMessageAttachmentDidBecomeAvailableNotification = @"AIQMessageAttachmentDidBecomeAvailableNotification";
NSString *const AIQMessageAttachmentDidBecomeUnavailableNotification = @"AIQMessageAttachmentDidBecomeUnavailableNotification";
NSString *const AIQMessageAttachmentDidFailEvent = @"AIQMessageAttachmentDidFailEvent";

NSString *const AIQDidQueueMessageNotification = @"AIQDidQueueMessageNotification";
NSString *const AIQDidAcceptMessageNotification = @"AIQDidAcceptMessageNotification";
NSString *const AIQDidRejectMessageNotification = @"AIQDidRejectMessageNotification";
NSString *const AIQDidDeliverMessageNotification = @"AIQDidDeliverMessageNotification";
NSString *const AIQDidFailMessageNotification = @"AIQDidFailMessageNotification";

NSString *const AIQMessageTypeUserInfoKey = @"AIQMessageTypeUserInfoKey";
NSString *const AIQMessageDestinationUserInfoKey = @"AIQMessageDestinationUserInfoKey";

@interface AIQSynchronization ()

- (id<AIQSynchronizer>)synchronizerForType:(NSString *)type;

@end

@interface AIQMessaging () {
    AIQContext *_context;
    AIQSession *_session;
    FMDatabasePool *_pool;
    NSString *_solution;
    NSString *_taskId;
    NSString *_basePath;
    BOOL _hasMessages;
    NSTimeInterval _nextActionDate;
}

@end

@implementation AIQMessaging

- (id)initForSession:(id)session solution:(NSString *)solution error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! solution) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Solution not specified"];
        }
        return nil;
    }

    self = [super init];
    if (self) {
        _session = session;
        _solution = solution;
        _basePath = [[session valueForKey:@"basePath"] stringByAppendingPathComponent:solution];
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];

        NSError *localError = nil;
        _context = [session context:&localError];
        if (! _context) {
            AIQLogCWarn(1, @"Did fail to retrieve context: %@", localError.localizedDescription);
        }
    }
    
    return self;
}

- (BOOL)messageExistsWithId:(NSString *)identifier {
    if (! identifier) {
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM somessages WHERE solution = ? AND identifier = ?",
                           _solution, identifier];
        if (! rs) {
            return;
        }
        
        result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
        [rs close];
    }];
    
    return result;
}

- (NSDictionary *)messageForId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT m.type, m.created, m.activeFrom, m.timeToLive, m.read, d.launchable, d.data FROM somessages m, documents d "
                           "WHERE m.solution = ? "
                           "AND m.solution = d.solution "
                           "AND m.identifier = ? "
                           "AND m.identifier = d.identifier "
                           "AND DATETIME(m.activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
                           "AND DATETIME(m.activeFrom / 1000 + m.timeToLive, 'unixepoch') >= DATETIME('now')",
                           _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
            }
            return;
        }
        
        NSMutableDictionary *mutable = [NSMutableDictionary dictionary];
        mutable[kAIQDocumentId] = identifier;
        if (! [rs columnIndexIsNull:5]) {
            mutable[kAIQDocumentLaunchableId] = [rs stringForColumnIndex:5];
        }
        mutable[kAIQMessageType] = [rs stringForColumnIndex:0];
        mutable[kAIQMessageCreated] = [rs objectForColumnIndex:1];
        mutable[kAIQMessageActiveFrom] = [rs objectForColumnIndex:2];
        mutable[kAIQMessageTimeToLive] = [rs objectForColumnIndex:3];
        mutable[kAIQMessageRead] = @([rs boolForColumnIndex:4]);
        
        NSDictionary *document = [[rs dataForColumnIndex:6] JSONObject];
        
        NSError *localError = nil;
        mutable[kAIQMessageRelevant] = @([self isRelevant:document error:&localError]);
//        if (localError) {
//            [rs close];
//            if (error) {
//                *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
//            }
//            return;
//        }
        
        mutable[kAIQMessagePayload] = document[kAIQMessagePayload];
        
        NSDictionary *notification = document[@"notification"];
        if (notification) {
            if (notification[kAIQMessageText]) {
                mutable[kAIQMessageText] = notification[kAIQMessageText];
            }
            if (notification[kAIQMessageSound]) {
                mutable[kAIQMessageSound] = notification[kAIQMessageSound];
            }
            if (notification[kAIQMessageVibrate]) {
                mutable[kAIQMessageVibrate] = notification[kAIQMessageVibrate];
            }
        }
        
        result = [mutable copy];
        
        [rs close];
    }];

    return result;
}

- (BOOL)messagesOfType:(NSString *)type
                 order:(AIQMessageOrder)order
             processor:(void (^)(NSDictionary *, NSError **))processor
                 error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (! type) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"];
        }
        return NO;
    }
    
    if (! processor) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"];
        }
        return NO;
    }

    __block BOOL result = YES;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs;
        
        if (order == AIQMessageOrderAscending) {
            rs = [db executeQuery:@"SELECT m.identifier, m.created, m.activeFrom, m.timeToLive, m.read, d.launchable, d.data FROM somessages m, documents d "
                  "WHERE m.solution = ? "
                  "AND m.solution = d.solution "
                  "AND m.type = ? "
                  "AND m.identifier = d.identifier "
                  "AND DATETIME(m.activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
                  "AND DATETIME(m.activeFrom / 1000 + m.timeToLive, 'unixepoch') >= DATETIME('now') "
                  "ORDER BY activeFrom ASC, created ASC",
                  _solution, type];
        } else {
            rs = [db executeQuery:@"SELECT m.identifier, m.created, m.activeFrom, m.timeToLive, m.read, d.launchable, d.data FROM somessages m, documents d "
                  "WHERE m.solution = ? "
                  "AND m.solution = d.solution "
                  "AND m.type = ? "
                  "AND m.identifier = d.identifier "
                  "AND DATETIME(m.activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
                  "AND DATETIME(m.activeFrom / 1000 + m.timeToLive, 'unixepoch') >= DATETIME('now') "
                  "ORDER BY activeFrom DESC, created DESC",
                  _solution, type];
        }
        
        if (! rs) {
            result = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        while ([rs next]) {
            NSMutableDictionary *mutable = [NSMutableDictionary dictionary];
            mutable[kAIQDocumentId] = [rs stringForColumnIndex:0];
            if (! [rs columnIndexIsNull:5]) {
                mutable[kAIQDocumentLaunchableId] = [rs stringForColumnIndex:5];
            }
            mutable[kAIQMessageType] = type;
            mutable[kAIQMessageCreated] = [rs objectForColumnIndex:1];
            mutable[kAIQMessageActiveFrom] = [rs objectForColumnIndex:2];
            mutable[kAIQMessageTimeToLive] = [rs objectForColumnIndex:3];
            mutable[kAIQMessageRead] = @([rs boolForColumnIndex:4]);
            
            NSDictionary *document = [[rs dataForColumnIndex:6] JSONObject];
            
            NSError *localError = nil;
            mutable[kAIQMessageRelevant] = @([self isRelevant:document error:nil]);
//            mutable[kAIQMessageRelevant] = @([self isRelevant:document error:&localError]);
//            if (localError) {
//                result = NO;
//                if (error) {
//                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
//                }
//                break;
//            }
            
            mutable[kAIQMessagePayload] = document[kAIQMessagePayload];
            
            NSDictionary *notification = document[@"notification"];
            if (notification) {
                if (notification[kAIQMessageText]) {
                    mutable[kAIQMessageText] = notification[kAIQMessageText];
                }
                if (notification[kAIQMessageSound]) {
                    mutable[kAIQMessageSound] = notification[kAIQMessageSound];
                }
                if (notification[kAIQMessageVibrate]) {
                    mutable[kAIQMessageVibrate] = notification[kAIQMessageVibrate];
                }
            }
            
            processor(mutable, &localError);
            if (localError) {
                result = NO;
                if (error) {
                    *error = localError;
                }
                break;
            }
        }
        
        [rs close];
    }];
    
    return result;
}

- (BOOL)markMessageAsReadForId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }

    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type FROM somessages WHERE solution = ? AND identifier = ? "
                           "AND DATETIME(activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
                           "AND DATETIME(activeFrom / 1000 + timeToLive, 'unixepoch') >= DATETIME('now')",
                           _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
            }
            return;
        }
        
        NSString *type = [rs stringForColumnIndex:0];
        [rs close];
        
        if ([db executeUpdate:@"UPDATE somessages SET read = ? WHERE solution = ? AND identifier = ?",
             @YES, _solution, identifier]) {
            result = YES;
            
            NOTIFY(AIQDidReadMessageNotification, self, (@{AIQDocumentIdUserInfoKey: identifier, AIQMessageTypeUserInfoKey: type}));
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];

    return result;
}

- (BOOL)deleteMessageWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    __block BOOL result = NO;

    [_pool inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"DELETE FROM somessages WHERE solution = ? AND identifier = ? "
               "AND DATETIME(activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
               "AND DATETIME(activeFrom / 1000 + timeToLive, 'unixepoch') >= DATETIME('now')",
               _solution, identifier]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ([db changes] != 1) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
            }
            return;
        }
        
        result = [self deleteMessageDocumentWithId:identifier solution:_solution inDatabase:db error:error];
    }];
    
    [((AIQMessagingSynchronizer *)[[_session synchronization:nil] synchronizerForType:@"_backendmessage"]) scheduleNextNotification];

    return result;
}

- (BOOL)attachmentWithName:(NSString *)name existsForMessageWithId:(NSString *)identifier {
    if (! name) {
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM attachments a, somessages m "
                           "WHERE m.solution = ? AND m.solution = a.solution AND m.identifier = ? AND m.identifier = a.identifier AND a.name = ?"
                           "AND DATETIME(m.activeFrom / 1000, 'unixepoch') <= DATETIME('now') "
                           "AND DATETIME(m.activeFrom / 1000 + m.timeToLive, 'unixepoch') >= DATETIME('now')",
                           _solution, identifier, name];
        if (! rs) {
            return;
        }
        
        result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
        [rs close];
    }];
    
    return result;
}

- (NSDictionary *)attachmentWithName:(NSString *)name forMessageWithId:(NSString *)identifier error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! [self messageExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        [rs close];
        
        rs = [db executeQuery:@"SELECT contentType, status, state, rejectionReason, revision FROM attachments "
              "WHERE solution = ? AND identifier = ? AND name = ? AND status != ?",
              _solution, identifier, name, @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            if ([rs next]) {
                NSMutableDictionary *data = [NSMutableDictionary dictionary];
                data[kAIQAttachmentName] = name;
                data[kAIQAttachmentContentType] = [rs stringForColumnIndex:0];
                data[kAIQAttachmentStatus] = [rs objectForColumnIndex:1];
                data[kAIQAttachmentState] = [rs objectForColumnIndex:2];
                if (! [rs columnIndexIsNull:3]) {
                    data[kAIQAttachmentRejectionReason] = [rs objectForColumnIndex:3];
                }
                data[kAIQAttachmentRevision] = [rs objectForColumnIndex:4];
                result = [data copy];
            } else if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
            [rs close];
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];
    
    return result;
}

- (NSArray *)attachmentsForMessageWithId:(NSString *)identifier error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! [self messageExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
        }
        return nil;
    }
    
    __block NSArray *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        [rs close];
        
        rs = [db executeQuery:@"SELECT name, contentType, status, state, rejectionReason, revision FROM attachments "
              "WHERE solution = ? AND identifier = ? AND status != ?",
              _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        NSMutableArray *mutable = [NSMutableArray array];
        while ([rs next]) {
            NSMutableDictionary *data = [NSMutableDictionary dictionary];
            data[kAIQAttachmentName] = [rs stringForColumnIndex:0];
            data[kAIQAttachmentContentType] = [rs stringForColumnIndex:1];
            data[kAIQAttachmentStatus] = [rs objectForColumnIndex:2];
            data[kAIQAttachmentState] = [rs objectForColumnIndex:3];
            if (! [rs columnIndexIsNull:4]) {
                data[kAIQAttachmentRejectionReason] = [rs objectForColumnIndex:4];
            }
            data[kAIQAttachmentRevision] = [rs objectForColumnIndex:5];
            [mutable addObject:[data copy]];
        }
        [rs close];
        result = [mutable copy];
    }];
    
    return result;
}

- (NSData *)dataForAttachmentWithName:(NSString *)name fromMessageWithId:(NSString *)identifier error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! [self messageExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
        }
        return nil;
    }
    
    __block NSData *data = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM attachments a, documents d WHERE a.solution = ? AND a.identifier = ? AND a.name = ? AND a.status != ? AND d.status != ? AND a.solution = d.solution AND a.identifier = d.identifier",
                           _solution, identifier, name, @(AIQSynchronizationStatusDeleted), @(AIQSynchronizationStatusDeleted)];
        BOOL exists = NO;
        if (rs) {
            exists = ([rs next]) && ([rs intForColumnIndex:0] == 1);
            [rs close];
        }
        if (! exists) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
        }
        
        NSString *path = [[_basePath stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (! [fileManager fileExistsAtPath:path]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorResourceNotFound message:@"Resource not found"];
            }
            return;
        }
        
        data = [fileManager contentsAtPath:path];
    }];
    
    return data;
}

- (void)close {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _context = nil;
    _session = nil;
    _pool = nil;
    _solution = nil;
    _taskId = nil;
    _basePath = nil;
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
                           to:(NSString *)destination
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:@[] from:nil to:destination urgent:NO expectResponse:YES error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                           to:(NSString *)destination
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:attachments from:nil to:destination urgent:NO expectResponse:YES error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
                           to:(NSString *)destination
                       urgent:(BOOL)urgent
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:@[] from:nil to:destination urgent:urgent expectResponse:YES error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
                           to:(NSString *)destination
               expectResponse:(BOOL)expectResponse
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:@[] from:nil to:destination urgent:NO expectResponse:expectResponse error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                           to:(NSString *)destination
                       urgent:(BOOL)urgent
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:attachments from:nil to:destination urgent:urgent expectResponse:YES error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                           to:(NSString *)destination
               expectResponse:(BOOL)expectResponse
                        error:(NSError * __autoreleasing *)error {
    return [self sendMessage:payload withAttachments:attachments from:nil to:destination urgent:NO expectResponse:expectResponse error:error];
}

- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                         from:(NSString *)identifier
                           to:(NSString *)destination
                       urgent:(BOOL)urgent
               expectResponse:(BOOL)expectResponse
                        error:(NSError * __autoreleasing *)error {
    if (error) {
        *error = nil;
    }

    if (! payload) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Payload not specified"];
        }
        return nil;
    }

    if (identifier) {
        __block BOOL success = YES;
        [_pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM documents d, attachments a "
                               "WHERE d.solution = ? AND a.solution = d.solution AND d.identifier = ? AND d.identifier = a.identifier AND d.type = '_launchable' AND a.name = 'content' AND a.state = ?",
                               _solution, identifier, @(AIQAttachmentStateAvailable)];
            if (! rs) {
                success = NO;
                return;
            }
            
            success = ([rs next]) && ([rs intForColumnIndex:0] == 1);
            [rs close];
        }];
        
        if (! success) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Sender not found"];
            }
            return nil;
        }
    }
    
    if ((! destination) || (destination.length == 0)) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Destination not specified"];
        }
        return nil;
    }
    
    if (attachments) {
        NSCountedSet *set = [NSCountedSet setWithArray:[attachments valueForKey:@"name"]];
        for (NSString *name in set) {
            if ([set countForObject:name] != 1) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Duplicate attachment name"];
                }
                return nil;
            }
        }
        
        for (NSDictionary *attachment in attachments) {
            NSString *contentType = attachment[@"contentType"];
            if ((! contentType) || (contentType.length == 0)) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Content type not specified"];
                }
                return nil;
            }
            NSString *resourceUrl = attachment[@"resourceUrl"];
            if ((! resourceUrl) || (resourceUrl.length == 0)) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Resource not specified"];
                }
                return nil;
            }
            
            if (! [self dataExistsForURL:resourceUrl]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorResourceNotFound message:@"Resource not found"];
                }
                return nil;
            }
        }
    }
    
    NSString *messageIdentifier = [[NSUUID UUID] UUIDString];
    __block NSDictionary *status;

    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        long long timestamp = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        if (! [db executeUpdate:@"INSERT INTO comessages (solution, identifier, destination, payload, urgent, launchable, created, expectResponse)"
               "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
               _solution,
               messageIdentifier,
               destination,
               [payload JSONData],
               @(urgent),
               identifier,
               @(timestamp),
               @(expectResponse)]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }

        if (attachments) {
            for (NSDictionary *attachment in attachments) {
                NSString *contentType = attachment[@"contentType"];
                NSString *name = attachment[@"name"];
                NSString *resourceUrl = attachment[@"resourceUrl"];
                if (! name) {
                    name = [[NSUUID UUID] UUIDString];
                }
                
                if (! [db executeUpdate:@"INSERT INTO coattachments (solution, identifier, name, contentType, link) VALUES (?, ?, ?, ?, ?)",
                       _solution, messageIdentifier, name, contentType, resourceUrl]) {
                    *rollback = YES;
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                    }
                    return;
                }
            }
        }
        
        status = @{kAIQDocumentId: messageIdentifier, kAIQMessageDestination: destination, kAIQMessageCreated: @(timestamp)};
    }];

    NOTIFY(AIQDidQueueMessageNotification, self, (@{AIQDocumentIdUserInfoKey: messageIdentifier, AIQMessageDestinationUserInfoKey: destination, AIQSolutionUserInfoKey: _solution}));

    if (urgent) {
        AIQLogCInfo(1, @"Message %@ is urgent, forcing push", messageIdentifier);
        [((AIQMessagingSynchronizer *)[[_session synchronization:nil] synchronizerForType:@"_backendmessage"]) pushMessages];
    }

    return status;
}

- (NSDictionary *)statusOfMessageWithId:(NSString *)identifier error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    __block NSMutableDictionary *status = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT destination, created, state, response FROM comessages WHERE solution = ? AND identifier = ?",
                           _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ([rs next]) {
            status = [NSMutableDictionary dictionary];
            status[kAIQDocumentId] = identifier;
            status[kAIQMessageDestination] = [rs stringForColumnIndex:0];
            status[kAIQMessageCreated] = [rs objectForColumnIndex:1];
            status[kAIQMessageState] = [rs objectForColumnIndex:2];
            if (! [rs columnIndexIsNull:3]) {
                status[kAIQMessageBody] = [rs stringForColumnIndex:3];
            }
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Message not found"];
        }
        [rs close];
    }];
    
    return status ? [status copy] : nil;
}

- (BOOL)statusesOfMessagesForDestination:(NSString *)destination
                               processor:(void (^)(NSDictionary *, NSError **))processor
                                   error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    
    if (! destination) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Destination not specified"];
        }
        return NO;
    }

    __block BOOL result = YES;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT identifier, created, state, response FROM comessages WHERE solution = ? AND destination = ?",
                           _solution, destination];
        if (! rs) {
            result = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        while ([rs next]) {
            NSMutableDictionary *status = [NSMutableDictionary dictionary];
            status[kAIQDocumentId] = [rs stringForColumnIndex:0];
            status[kAIQMessageDestination] = destination;
            status[kAIQMessageCreated] = [rs objectForColumnIndex:1];
            status[kAIQMessageState] = [rs objectForColumnIndex:2];
            if (! [rs columnIndexIsNull:3]) {
                status[kAIQMessageBody] = [rs stringForColumnIndex:3];
            }
            
            NSError *localError = nil;
            processor(status, &localError);
            if (localError) {
                result = NO;
                if (error) {
                    *error = localError;
                }
                break;
            }
        }
        
        [rs close];
    }];
    
    return result;
}

#pragma mark - Private API

- (BOOL)dataExistsForURL:(NSString *)resourceUrl {
    NSURL *url;
    if ([resourceUrl rangeOfString:@"://"].location == NSNotFound) {
        // file URL
        url = [NSURL fileURLWithPath:resourceUrl];
    } else {
        url = [NSURL URLWithString:resourceUrl];
    }
    
    if ([url.scheme hasPrefix:@"aiq-"]) {
        return YES;
    } else if ([url.scheme isEqualToString:@"assets-library"]) {
        return [self existsInAssetsLibrary:url];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
        request.HTTPMethod = @"HEAD";
        [request setValue:@"close" forHTTPHeaderField:@"Connection"];
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if (response.statusCode == 301) {
            NSString *location = response.allHeaderFields[@"Location"];
            if (location) {
                return [self dataExistsForURL:location];
            } else {
                return NO;
            }
        } else {
            return (data != nil) && (response.expectedContentLength > 0);
        }
    }
}

-(BOOL)existsInAssetsLibrary:(NSURL*)path {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    __block BOOL flag = YES;
    
    ALAssetsLibrary *assetslibrary = [ALAssetsLibrary new];
    [assetslibrary assetForURL:path resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *representation = [asset defaultRepresentation];
        CGImageRef reference = [representation fullScreenImage];
        if (reference) {
            flag = YES;
            dispatch_group_leave(group);
        }
    } failureBlock:^(NSError *error) {
        flag = NO;
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return flag;
}

- (BOOL)isRelevant:(NSDictionary *)message
             error:(NSError *__autoreleasing *)error {
    if (! _context) {
        AIQLogCWarn(1, @"No context, message %@ is always relevant", message[kAIQDocumentId]);
        return YES;
    }

    NSDictionary *condition = message[@"notification"][@"condition"];
    if (condition) {
        NSArray *keys = [condition allKeys];
        for (int i = 0; i < keys.count; i++) {
            NSString *key = keys[i];
            id provider = [_context valueForName:key error:error];
            if (provider) {
                if (! [provider matches:condition[key] error:error]) {
                    return NO;
                }
            } else {
                return NO;
            }
        }
    }

    return YES;
}

- (BOOL)deleteMessageDocumentWithId:(NSString *)identifier solution:(NSString *)solution inDatabase:(FMDatabase *)db error:(NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", solution, identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
        return NO;
    }
    
    NSString *path = [[_basePath stringByAppendingPathComponent:solution] stringByAppendingPathComponent:identifier];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path]) {
        [fileManager removeItemAtPath:path error:nil];
    }

    return YES;
}

@end
