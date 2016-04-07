#import <FMDB/FMDB.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQSession.h"


NSString *const kAIQDocumentId = @"_id";
NSString *const kAIQDocumentType = @"_type";
NSString *const kAIQDocumentRevision = @"_rev";
NSString *const kAIQDocumentLaunchableId = @"_launchable";
NSString *const kAIQDocumentStatus = @"_status";
NSString *const kAIQDocumentRejectionReason = @"_reason";

NSString *const kAIQAttachmentName = @"name";
NSString *const kAIQAttachmentContentType = @"contentType";
NSString *const kAIQAttachmentRevision = @"_rev";
NSString *const kAIQAttachmentStatus = @"status";
NSString *const kAIQAttachmentState = @"state";
NSString *const kAIQAttachmentRejectionReason = @"reason";

@interface AIQDataStore () {
    NSFileManager *_fileManager;
    NSString *_basePath;
    FMDatabasePool *_pool;
    NSString *_solution;
}

@end

@implementation AIQDataStore

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! solution) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Solution not specified"];
        }
        return nil;
    }
    
    if (! session) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session not specified"];
        }
        return nil;
    }
    
    if (! [session isOpen]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Session is closed"];
        }
        return nil;
    }
    
    self = [super init];
    if (self) {
        _basePath = [[session valueForKey:@"basePath"] stringByAppendingPathComponent:solution];
        _solution = solution;
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
        _fileManager = [NSFileManager new];
    }
    
    return self;
}

- (BOOL)documentExistsWithId:(NSString *)identifier {
    if (! identifier) {
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
            [rs close];
        }
    }];
    
    return result;
}

- (NSDictionary *)documentForId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
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
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type, status, rejectionReason, data, revision, launchable FROM documents "
                           "WHERE solution = ? AND identifier = ? AND status != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            if ([rs next]) {
                NSMutableDictionary *data = [[rs dataForColumnIndex:3] JSONObject];
                data[kAIQDocumentId] = identifier;
                data[kAIQDocumentType] = [rs stringForColumnIndex:0];
                data[kAIQDocumentStatus] = [rs objectForColumnIndex:1];
                if (! [rs columnIndexIsNull:2]) {
                    data[kAIQDocumentRejectionReason] = [rs objectForColumnIndex:2];
                }
                data[kAIQDocumentRevision] = [rs objectForColumnIndex:4];
                if (! [rs columnIndexIsNull:5]) {
                    data[kAIQDocumentLaunchableId] = [rs stringForColumnIndex:5];
                }
                result = [data copy];
                [rs close];
            } else if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];
    
    return result;
}

- (BOOL)documentTypes:(void (^)(NSString *, NSError *__autoreleasing *))processor error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! processor) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"];
        }
        return NO;
    }
    
    __block BOOL result = YES;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT DISTINCT type FROM documents WHERE solution = ? AND type NOT LIKE '\\_%' ESCAPE '\\' ORDER BY type ASC", _solution];
        if (! rs) {
            result = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        while ([rs next]) {
            NSString *type = [rs stringForColumnIndex:0];
            NSError *localError = nil;
            processor(type, &localError);
            if (localError) {
                [rs close];
                result = NO;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                break;
            }
        }
        [rs close];
    }];
    
    return result;
}

- (BOOL)documentsOfType:(NSString *)type
              processor:(void (^)(NSDictionary *, NSError *__autoreleasing *))processor
                  error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! type) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"];
        }
        return NO;
    }
    
    if ([type characterAtIndex:0] == '_') {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Restricted document type"];
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
        FMResultSet *rs = [db executeQuery:@"SELECT identifier, status, rejectionReason, data, revision, launchable FROM documents "
                           "WHERE solution = ? AND type = ? AND status != ? "
                           "ORDER BY identifier ASC",
                           _solution, type, @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            NSError *localError = nil;
            while ([rs next]) {
                @autoreleasepool {
                    NSMutableDictionary *data = [[[rs dataForColumnIndex:3] JSONObject] mutableCopy];
                    data[kAIQDocumentId] = [rs stringForColumnIndex:0];
                    data[kAIQDocumentType] = type;
                    data[kAIQDocumentStatus] = [rs objectForColumnIndex:1];
                    if (! [rs columnIndexIsNull:2]) {
                        data[kAIQDocumentRejectionReason] = [rs objectForColumnIndex:2];
                    }
                    data[kAIQDocumentRevision] = [rs objectForColumnIndex:4];
                    if (! [rs columnIndexIsNull:5]) {
                        data[kAIQDocumentLaunchableId] = [rs stringForColumnIndex:5];
                    }
                    processor(data, &localError);
                    if (localError) {
                        result = NO;
                        if (error) {
                            *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                        }
                        break;
                    }
                }
            }
            [rs close];
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];
    
    return result;
}

- (NSDictionary *)createDocumentOfType:(NSString *)type
                            withFields:(NSDictionary *)fields
                                 error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    
    if (! type) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"];
        }
        return nil;
    }
    
    if ([type characterAtIndex:0] == '_') {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Restricted document type"];
        }
        return nil;
    }
    
    if (! fields) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Fields not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        NSString *identifier = [[NSUUID UUID] UUIDString];
        
        NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
        for (NSString *field in fields) {
            if ([field characterAtIndex:0] != '_') {
                filtered[field] = fields[field];
            }
        }
        
        if (! [db executeUpdate:@"INSERT INTO documents (solution, identifier, type, status, data) VALUES (?, ?, ?, ?, ?)",
                                 _solution, identifier, type, @(AIQSynchronizationStatusCreated), [filtered JSONData]]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        filtered[kAIQDocumentId] = identifier;
        filtered[kAIQDocumentType] = type;
        filtered[kAIQDocumentStatus] = @(AIQSynchronizationStatusCreated);
        result = [filtered copy];
    }];
    
    return result;
}

- (NSDictionary *)updateFields:(NSDictionary *)fields
             forDocumentWithId:(NSString *)identifier
                         error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! fields) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Fields not specified"];
        }
        return nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status, type FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            if ([rs next]) {
                AIQSynchronizationStatus status = [rs intForColumnIndex:0];
                status = (status == AIQSynchronizationStatusCreated) ? AIQSynchronizationStatusCreated : AIQSynchronizationStatusUpdated;
                NSString *type = [rs stringForColumnIndex:1];
                [rs close];
                
                NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
                for (NSString *field in fields) {
                    if ([field characterAtIndex:0] != '_') {
                        filtered[field] = fields[field];
                    }
                }
                
                if ([db executeUpdate:@"UPDATE documents SET status = ?, data = ?, rejectionReason = NULL WHERE solution = ? AND identifier = ?",
                                       @(status), [filtered JSONData], _solution, identifier]) {
                    filtered[kAIQDocumentId] = identifier;
                    filtered[kAIQDocumentType] = type;
                    filtered[kAIQDocumentStatus] = @(status);
                    result = [filtered copy];
                } else if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
            } else if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];
    
    return result;
}

- (BOOL)deleteDocumentWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
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
    
    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"SELECT status, revision FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        
        AIQSynchronizationStatus status = [rs intForColumnIndex:0];
        unsigned long long revision = [rs unsignedLongLongIntForColumnIndex:1];
        [rs close];
        NSMutableArray *paths = [NSMutableArray array];
        
        if ((status == AIQSynchronizationStatusCreated) || ((status == AIQSynchronizationStatusRejected) && (revision == 0))) {
            // Just delete the document and its attachments
            if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?", _solution, identifier]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
            
            if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ?", _solution, identifier]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
            
            [paths addObject:[_basePath stringByAppendingPathComponent:identifier]];
        } else {
            // Send delete request to the backend
            if (! [db executeUpdate:@"UPDATE documents SET status = ? WHERE solution = ? AND identifier = ?",
                                     @(AIQSynchronizationStatusDeleted), _solution, identifier]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
            if (! [db executeUpdate:@"UPDATE attachments SET status = ? WHERE solution = ? AND identifier = ?",
                                     @(AIQSynchronizationStatusDeleted), _solution, identifier]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
        }
        
        for (NSString *path in paths) {
            [_fileManager removeItemAtPath:path error:nil];
        }
        
        result = YES;
    }];
    
    return result;
}

- (BOOL)attachmentWithName:(NSString *)name existsForDocumentWithId:(NSString *)identifier {
    if ((! name) || (! identifier)) {
        return NO;
    }
    
    __block BOOL result = NO;
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM attachments a, documents d WHERE a.solution = ? AND a.identifier = ? AND a.name = ? AND a.status != ? AND d.status != ? AND a.solution = d.solution AND a.identifier = d.identifier AND d.type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, name, @(AIQSynchronizationStatusDeleted), @(AIQSynchronizationStatusDeleted)];
        if (rs) {
            result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
            [rs close];
        }
    }];
    
    return result;
}

- (NSDictionary *)attachmentWithName:(NSString *)name
                   forDocumentWithId:(NSString *)identifier
                               error:(NSError *__autoreleasing *)error {
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
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
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

- (BOOL)attachmentsForDocumentWithId:(NSString *)identifier
                           processor:(void (^)(NSDictionary *, NSError *__autoreleasing *))processor
                               error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
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
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
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
        
        NSError *localError = nil;
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
            
            processor(data, &localError);
            if (localError) {
                result = NO;
                *error = localError;
                break;
            }
        }
        
        [rs close];
    }];
    
    return result;
}

- (NSArray *)attachmentsForDocumentWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    __block NSArray *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
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

- (NSDictionary *)createAttachmentWithName:(NSString *)name
                               contentType:(NSString *)contentType
                                   andData:(NSData *)data
                         forDocumentWithId:(NSString *)identifier
                                     error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    
    if (! contentType) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Content type not specified"];
        }
        return nil;
    }
    
    if (! data) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Resource not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        [rs close];
        
        rs = [db executeQuery:@"SELECT status FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", _solution, identifier, name];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        AIQSynchronizationStatus status;
        if ([rs next]) {
            status = [rs intForColumnIndex:0];
            [rs close];
            if (status == AIQSynchronizationStatusDeleted) {
                // update attachment
                if (! [db executeUpdate:@"UPDATE attachments SET contentType = ?, state = ?, status = ? WHERE solution = ? AND identifier = ? AND name = ?",
                       contentType, @(AIQAttachmentStateAvailable), @(AIQSynchronizationStatusUpdated), _solution, identifier, name]) {
                    *rollback = YES;
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                    }
                    return;
                }
            } else {
                // duplicate name, fail
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Duplicate attachment name"];
                }
                return;
            }
        } else {
            // create attachment
            [rs close];
            if (! [db executeUpdate:@"INSERT INTO attachments (solution, identifier, name, contentType, state, status) VALUES (?, ?, ?, ?, ?, ?)",
                                     _solution, identifier, name, contentType, @(AIQAttachmentStateAvailable), @(AIQSynchronizationStatusCreated)]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
            status = AIQSynchronizationStatusCreated;
        }
        
        NSString *folder = [_basePath stringByAppendingPathComponent:identifier];
        NSError *localError = nil;
        if (! [_fileManager fileExistsAtPath:folder]) {
            if (! [_fileManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFileProtectionKey: NSFileProtectionComplete} error:&localError]) {
                *rollback = YES;
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                }
                return;
            }
        }
        
        if (! [data writeToFile:[folder stringByAppendingPathComponent:name] options:NSDataWritingFileProtectionComplete error:&localError]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
            }
            return;
        }
        
        result = @{kAIQAttachmentName: name,
                   kAIQAttachmentContentType: contentType,
                   kAIQAttachmentStatus: @(status),
                   kAIQAttachmentState: @(AIQAttachmentStateAvailable)};
    }];
    
    return result;
}

- (NSDictionary *)updateData:(NSData *)data
             withContentType:(NSString *)contentType
       forAttachmentWithName:(NSString *)name
          fromDocumentWithId:(NSString *)identifier
                       error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    
    if (! contentType) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Content type not specified"];
        }
        return nil;
    }
    
    if (! data) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Resource not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        [rs close];
        
        rs = [db executeQuery:@"SELECT status FROM attachments WHERE solution = ? AND identifier = ? AND name = ? AND status != ?",
                               _solution, identifier, name, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
            return;
        }
        
        AIQSynchronizationStatus status = ([rs intForColumnIndex:0] == AIQSynchronizationStatusCreated) ? AIQSynchronizationStatusCreated : AIQSynchronizationStatusUpdated;
        [rs close];
        
        if (! [db executeUpdate:@"UPDATE attachments SET contentType = ?, status = ?, state = ? WHERE solution = ? AND identifier = ? AND name = ?",
               contentType, @(status), @(AIQAttachmentStateAvailable), _solution, identifier, name]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        NSString *path = [[_basePath stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
        NSError *localError = nil;
        if (! [data writeToFile:path options:NSDataWritingFileProtectionComplete | NSDataWritingAtomic error:&localError]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
            }
            return;
        }
        
        result = @{kAIQAttachmentName: name,
                   kAIQAttachmentContentType: contentType,
                   kAIQAttachmentStatus: @(status),
                   kAIQAttachmentState: @(AIQAttachmentStateAvailable)};
    }];
    
    return result;
}

- (BOOL)deleteAttachmentWithName:(NSString *)name
              fromDocumentWithId:(NSString *)identifier
                           error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return NO;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT status FROM documents WHERE solution = ? AND identifier = ? AND status != ? AND type NOT LIKE '\\_%' ESCAPE '\\'",
                                            _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        [rs close];
        
        rs = [db executeQuery:@"SELECT status, revision FROM attachments WHERE solution = ? AND identifier = ? AND name = ? AND status != ?",
                               _solution, identifier, name, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
            return;
        }
        
        AIQSynchronizationStatus status = [rs intForColumnIndex:0];
        unsigned long long revision = [rs unsignedLongLongIntForColumnIndex:1];
        [rs close];
        
        if ((status == AIQSynchronizationStatusCreated) || ((status == AIQSynchronizationStatusRejected) && (revision == 0))) {
            if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", _solution, identifier, name]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                } 
                return;
            }
            
            [_fileManager removeItemAtPath:[[_basePath stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name] error:nil];
        } else {
            if (! [db executeUpdate:@"UPDATE attachments SET status = ? WHERE solution = ? AND identifier = ? AND name = ?",
                   @(AIQSynchronizationStatusDeleted), _solution, identifier, name]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
                return;
            }
        }
        
        result = YES;
    }];
    
    return result;
}

- (NSData *)dataForAttachmentWithName:(NSString *)name fromDocumentWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    
    if (! [self documentExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
        }
        return nil;
    }
    
    if (! [self attachmentWithName:name existsForDocumentWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
        }
        return nil;
    }
    
    NSString *path = [[_basePath stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name];
    if (! [_fileManager fileExistsAtPath:path]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorResourceNotFound message:@"Resource not found"];
        }
        return nil;
    }
    
    return [_fileManager contentsAtPath:path];
}

- (NSData *)dataForAttachmentAtPath:(NSString *)path {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSData *data;

    if ([path hasPrefix:@"file:///"]) {
        NSString *absPath = [path stringByReplacingOccurrencesOfString:@"file://"
                                                            withString:@""];

        if (![fileManager fileExistsAtPath:absPath]) {
            NSLog(@"File not found: %@", absPath);
            return nil;
        }

        data = [fileManager contentsAtPath:absPath];

    } else if ([path hasPrefix:@"res:"]) {
        NSBundle* mainBundle = [NSBundle mainBundle];
        NSString* bundlePath = [[mainBundle bundlePath] stringByAppendingString:@"/"];

        NSString *absPath = [path pathComponents].lastObject;
        absPath = [bundlePath stringByAppendingString:absPath];

        if (![fileManager fileExistsAtPath:absPath]) {
            NSLog(@"File not found: %@", absPath);
            return nil;
        }
        
        data = [fileManager contentsAtPath:absPath];

    } else if ([path hasPrefix:@"file://"]) {
        NSBundle* mainBundle = [NSBundle mainBundle];
        NSString* bundlePath = [[mainBundle bundlePath]
                                stringByAppendingString:@"/"];

        NSString *absPath = [path stringByReplacingOccurrencesOfString:@"file:/"
                                                            withString:@"www"];

        absPath = [bundlePath stringByAppendingString:absPath];

        if (![fileManager fileExistsAtPath:absPath]) {
            NSLog(@"File not found: %@", absPath);
        }
        
        data = [fileManager contentsAtPath:absPath];

    } else if ([path hasPrefix:@"assets-library://"]) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        __block NSData *data = nil;

        ALAssetsLibrary *assetLibrary = [ALAssetsLibrary new];
        [assetLibrary assetForURL:[NSURL URLWithString:path] resultBlock:^(ALAsset *asset) {
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            Byte *buffer = (Byte*)malloc(rep.size);
            NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
            data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
            dispatch_group_leave(group);
        } failureBlock:^(NSError *error) {
            dispatch_group_leave(group);
        }];

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    } else if ([path hasPrefix:@"aiq-"]) {
        return [NSData dataWithContentsOfURL:[NSURL URLWithString:path]];

    } else {
        if (![fileManager fileExistsAtPath:path]) {
            NSLog(@"File not found: %@", path);
        }

        data = [fileManager contentsAtPath:path];
    }

    return data;
}

- (BOOL)hasUnsynchronizedDocumentsOfType:(NSString *)type {
    if (! type) {
        return NO;
    }
    
    __block BOOL has = NO;
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM documents WHERE TYPE = ? AND status != ?", type, @(AIQSynchronizationStatusSynchronized)];
        if (! rs) {
            return;
        }
        
        if ([rs next]) {
            has = [rs intForColumnIndex:0] != 0;
        }
        
        [rs close];
    }];
    
    return has;
}

- (void)close {
    if (_pool) {
        _pool = nil;
        _fileManager = nil;
        _basePath = nil;
        _solution = nil;
    }
}

- (void)dealloc {
    [self close];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<AIQDataStore: %p (%@)>", self, [_basePath lastPathComponent]];
}

@end
