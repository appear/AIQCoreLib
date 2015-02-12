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

#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQSession.h"
#import "FMDatabase.h"

NSString *const AIQGlobalSolution = @"_global";

NSString *const kAIQDocumentId = @"AIQDocumentId";
NSString *const kAIQDocumentRejectionReason = @"AIQDocumentRejectionReason";
NSString *const kAIQDocumentSynchronizationStatus = @"AIQDocumentSynchronizationStatus";
NSString *const kAIQDocumentType = @"AIQDocumentType";

NSString *const kAIQAttachmentContentType = @"AIQAttachmentContentType";
NSString *const kAIQAttachmentName = @"AIQAttachmentName";
NSString *const kAIQAttachmentRejectionReason = @"AIQAttachmentRejectionReason";
NSString *const kAIQAttachmentSynchronizationStatus = @"AIQAttachmentSynchronizationStatus";
NSString *const kAIQAttachmentState = @"AIQAttachmentState";

@interface AIQDataStore () {
    FMDatabasePool *_pool;
    NSString *_solution;
    NSString *_basePath;
    NSFileManager *_fileManager;
}

@end

@implementation AIQDataStore

- (instancetype)init {
    return nil;
}

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution {
    if (! session) {
        return nil;
    }

    if (! [session isOpen]) {
        return nil;
    }

    if (! solution) {
        return nil;
    }

    self = [super init];
    if (self) {
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
        _solution = solution;
        _basePath = [session valueForKey:@"basePath"];
        _fileManager = [NSFileManager new];
    }
    return self;
}

- (void)documentTypes:(void (^)(NSString *, NSError *__autoreleasing*))processor
              failure:(void (^)(NSError *))failure {
    if (! processor) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"]);
        }
        return;
    }

    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT DISTINCT type FROM documents "
                           "WHERE solution = ? AND type NOT LIKE '\\_%' ESCAPE '\\' AND synchronizationStatus != ? "
                           "ORDER BY type ASC",
                           _solution, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }

        NSError *error = nil;
        while ([rs next]) {
            processor([rs stringForColumnIndex:0], &error);
            if (error) {
                if (failure) {
                    failure(error);
                }
                break;
            }
        }

        [rs close];
    }];
}

- (void)documentsOfType:(NSString *)type
              processor:(void (^)(NSDictionary *, NSError *__autoreleasing *))processor
                failure:(void (^)(NSError *))failure {
    if (! type) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"]);
        }
        return;
    }

    if (! processor) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"]);
        }
        return;
    }

    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT identifier, synchronizationStatus, rejectionReason, content FROM documents "
                           "WHERE solution = ? AND type = ? AND type NOT LIKE '\\_%' ESCAPE '\\' AND synchronizationStatus != ? "
                           "ORDER BY type ASC, identifier ASC",
                           _solution, type, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }

        NSError *error = nil;
        while ([rs next]) {
            NSMutableDictionary *content = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:3]
                                                                           options:NSJSONReadingMutableContainers
                                                                             error:nil];
            content[kAIQDocumentId] = [rs stringForColumnIndex:0];
            content[kAIQDocumentType] = type;
            content[kAIQDocumentSynchronizationStatus] = [rs objectForColumnIndex:1];
            if (! [rs columnIndexIsNull:2]) {
                content[kAIQDocumentRejectionReason] = [rs objectForColumnIndex:2];
            }
            processor([content copy], &error);
            if (error) {
                if (failure) {
                    failure(error);
                }
                break;
            }
        }

        [rs close];
    }];
}

- (void)documentWithId:(NSString *)identifier
               success:(void (^)(NSDictionary *))success
               failure:(void (^)(NSError *))failure {
    if (! identifier) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"]);
        }
        return;
    }

    if (! success) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Success callback not specified"]);
        }
        return;
    }

    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type, synchronizationStatus, rejectionReason, content FROM documents "
                           "WHERE solution = ? AND identifier = ? AND type NOT LIKE '\\_%' ESCAPE '\\' AND synchronizationStatus != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }

        if ([rs next]) {
            NSMutableDictionary *content = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:3]
                                                                           options:NSJSONReadingMutableContainers
                                                                             error:nil];
            content[kAIQDocumentId] = identifier;
            content[kAIQDocumentType] = [rs stringForColumnIndex:0];
            content[kAIQDocumentSynchronizationStatus] = [rs objectForColumnIndex:1];
            if (! [rs columnIndexIsNull:2]) {
                content[kAIQDocumentRejectionReason] = [rs objectForColumnIndex:2];
            }
            success([content copy]);
        } else {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"]);
            }
        }

        [rs close];
    }];
}

- (void)createDocument:(NSDictionary *)fields
                ofType:(NSString *)type
               success:(void (^)(NSDictionary *))success
               failure:(void (^)(NSError *))failure {
    if (! type) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"]);
        }
        return;
    }

    if ([type characterAtIndex:0] == '_') {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Restricted type"]);
        }
        return;
    }

    if (! fields) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Fields not specified"]);
        }
        return;
    }

    NSMutableDictionary *filtered = [self filter:fields];
    NSString *identifier = [[NSUUID UUID] UUIDString];
    NSData *data = [NSJSONSerialization dataWithJSONObject:filtered options:kNilOptions error:nil];

    [_pool inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"INSERT INTO documents (solution, identifier, type, revision, synchronizationStatus, content)"
               "VALUES (?, ?, ?, ?, ?, ?)",
               _solution, identifier, type, @0, @(AIQSynchronizationStatusCreated), data]) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }
        
        if (success) {
            filtered[kAIQDocumentId] = identifier;
            filtered[kAIQDocumentType] = type;
            filtered[kAIQDocumentSynchronizationStatus] = @(AIQSynchronizationStatusCreated);
            success([filtered copy]);
        }
    }];
}

- (void)updateFields:(NSDictionary *)fields
    ofDocumentWithId:(NSString *)identifier
             success:(void (^)(NSDictionary *))success
             failure:(void (^)(NSError *))failure {
    if (! fields) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Fields not specified"]);
        }
        return;
    }
    
    if (! identifier) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"]);
        }
        return;
    }
    
    NSMutableDictionary *filtered = [self filter:fields];
    NSData *data = [NSJSONSerialization dataWithJSONObject:filtered options:kNilOptions error:nil];
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type, synchronizationStatus FROM documents "
                           "WHERE solution = ? AND identifier = ? AND type NOT LIKE '\\_%' ESCAPE '\\' AND synchronizationStatus != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"]);
            }
            return;
        }
        
        NSString *type = [rs stringForColumnIndex:0];
        AIQSynchronizationStatus status = [rs intForColumnIndex:1];
        [rs close];
        
        if (status != AIQSynchronizationStatusCreated) {
            status = AIQSynchronizationStatusUpdated;
        }
        
        if (! [db executeUpdate:@"UPDATE documents SET synchronizationStatus = ?, rejectionReason = ?, content = ? "
               "WHERE solution = ? AND identifier = ?",
               @(status), nil, data, _solution, identifier]) {
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }
        
        if (success) {
            filtered[kAIQDocumentId] = identifier;
            filtered[kAIQDocumentType] = type;
            filtered[kAIQDocumentSynchronizationStatus] = @(status);
            success([filtered copy]);
        }
    }];
}

- (void)deleteDocumentWithId:(NSString *)identifier
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *))failure {
    if (! identifier) {
        if (failure) {
            failure([AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"]);
        }
        return;
    }
    
    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"SELECT revision, synchronizationStatus FROM documents "
                           "WHERE solution = ? AND identifier = ? AND type NOT LIKE '\\_%' ESCAPE '\\' AND synchronizationStatus != ?",
                           _solution, identifier, @(AIQSynchronizationStatusDeleted)];
        if (! rs) {
            *rollback = YES;
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
            }
            return;
        }
        
        if (! [rs next]) {
            [rs close];
            *rollback = YES;
            if (failure) {
                failure([AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"]);
            }
            return;
        }
        
        unsigned long long revision = [rs unsignedLongLongIntForColumnIndex:0];
        AIQSynchronizationStatus status = [rs intForColumnIndex:1];
        [rs close];
        
        if ((status == AIQSynchronizationStatusCreated) ||
            ((status == AIQSynchronizationStatusRejected) && (revision == 0ull))) {
            if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ?",
                   _solution, identifier]) {
                *rollback = YES;
                if (failure) {
                    failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
                }
                return;
            }
            
            if (! [db executeUpdate:@"DELETE FROM documents WHERE solution = ? AND identifier = ?",
                   _solution, identifier]) {
                *rollback = YES;
                if (failure) {
                    failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
                }
                return;
            }
            
            NSString *path = [[_basePath stringByAppendingPathComponent:_solution] stringByAppendingPathComponent:identifier];
            if ([_fileManager fileExistsAtPath:path]) {
                NSError *error = nil;
                if (! [_fileManager removeItemAtPath:path error:&error]) {
                    *rollback = YES;
                    if (failure) {
                        failure([AIQError errorWithCode:AIQErrorContainerFault message:error.localizedDescription]);
                    }
                    return;
                }
            }
        } else {
            if (! [db executeUpdate:@"UPDATE documents SET synchronizationStatus = ? WHERE solution = ? AND identifier = ?",
                   @(AIQSynchronizationStatusDeleted), _solution, identifier]) {
                *rollback = YES;
                if (failure) {
                    failure([AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription]);
                }
                return;
            }
        }
        
        if (success) {
            success();
        }
    }];
}

#pragma mark - Private API

- (NSMutableDictionary *)filter:(NSDictionary *)dictionary {
    NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
    for (NSString *field in dictionary) {
        if ([field characterAtIndex:0] != '_') {
            filtered[field] = dictionary[field];
        }
    }
    return filtered;
}

@end
