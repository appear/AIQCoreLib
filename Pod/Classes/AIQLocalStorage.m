#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQJSON.h"
#import "AIQLocalStorage.h"
#import "AIQSession.h"

@interface AIQLocalStorage () {
    NSString *_basePath;
    NSString *_solution;
    FMDatabasePool *_pool;
    NSFileManager *_fileManager;
}

@end

@implementation AIQLocalStorage

- (void)close {
    _pool = nil;
}

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
        _basePath = [[[session valueForKey:@"basePath"] stringByAppendingPathComponent:solution] stringByAppendingPathComponent:@"local"];
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
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM localdocuments WHERE solution = ? AND identifier = ?", _solution, identifier];
        if (! rs) {
            return;
        }
        
        result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
        [rs close];
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
        FMResultSet *rs = [db executeQuery:@"SELECT type, data FROM localdocuments WHERE solution = ? AND identifier = ?", _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ([rs next]) {
            NSMutableDictionary *data = [[rs dataForColumnIndex:1] JSONObject];
            data[kAIQDocumentId] = identifier;
            data[kAIQDocumentType] = [rs stringForColumnIndex:0];
            result = [data copy];
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
        }
        [rs close];
    }];
    
    return result;
}

- (BOOL)documentsOfType:(NSString *)type processor:(void (^)(NSDictionary *, NSError **))processor error:(NSError *__autoreleasing *)error {
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
        FMResultSet *rs = [db executeQuery:@"SELECT identifier, data FROM localdocuments WHERE solution = ? AND type = ?", _solution, type];
        if (! rs) {
            result = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        NSError *localError = nil;
        while ([rs next]) {
            NSMutableDictionary *data = [[rs dataForColumnIndex:1] JSONObject];
            data[kAIQDocumentId] = [rs stringForColumnIndex:0];
            data[kAIQDocumentType] = type;
            processor(data, &localError);
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

- (NSDictionary *)createDocumentOfType:(NSString *)type withFields:(NSDictionary *)fields error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }


    if (! type) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Type not specified"];
        }
        return nil;
    }

    if (! fields) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Fields not specified"];
        }
        return nil;
    }

    NSString *identifier = fields[kAIQDocumentId];
    if (identifier) {
        if ([self documentExistsWithId:identifier]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Duplicate document identifier"];
            }
            return nil;
        }
    } else {
        identifier = [[NSUUID UUID] UUIDString];
    }

    __block NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
    for (NSString *field in fields) {
        if ([field characterAtIndex:0] != '_') {
            filtered[field] = fields[field];
        }
    }
    
    [_pool inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"INSERT INTO localdocuments (solution, identifier, type, data) VALUES (?, ?, ?, ?)",
               _solution, identifier, type, [filtered JSONData]]) {
            filtered = nil;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
        }
    }];
    
    if (! filtered) {
        return nil;
    }
    
    filtered[kAIQDocumentId] = identifier;
    filtered[kAIQDocumentType] = type;

    return [filtered copy];
}

- (NSDictionary *)updateFields:(NSDictionary *)fields forDocumentWithId:(NSString *)identifier error:(NSError *__autoreleasing *)error {
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
    
    __block NSMutableDictionary *filtered = [NSMutableDictionary dictionary];
    for (NSString *field in fields) {
        if ([field characterAtIndex:0] != '_') {
            filtered[field] = fields[field];
        }
    }
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type FROM localdocuments WHERE solution = ? AND identifier = ?", _solution, identifier];
        if (! rs) {
            filtered = nil;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (! [rs next]) {
            filtered = nil;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        
        
        NSString *type = [rs stringForColumnIndex:0];
        [rs close];
        
        if (! [db executeUpdate:@"UPDATE localdocuments SET data = ? WHERE solution = ? AND identifier = ?",
               [filtered JSONData], _solution, identifier]) {
            filtered = nil;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        filtered[kAIQDocumentId] = identifier;
        filtered[kAIQDocumentType] = type;
    }];
    
    return filtered ? [filtered copy] : nil;
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
    
    [_pool inDatabase:^(FMDatabase *db) {
        if ([db executeUpdate:@"DELETE FROM localdocuments WHERE solution = ? AND identifier = ?", _solution, identifier]) {
            if ([db changes] == 1) {
                NSString *path = [_basePath stringByAppendingPathComponent:identifier];
                if ([_fileManager fileExistsAtPath:path]) {
                    NSError *localError = nil;
                    if (! [_fileManager removeItemAtPath:path error:&localError]) {
                        if (error) {
                            *error = [AIQError errorWithCode:AIQErrorContainerFault message:localError.localizedDescription];
                        }
                        return;
                    }
                }
                
                result = YES;
            } else if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
        } else if (error) {
            *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
        }
    }];
    
    return result;
}

- (BOOL)attachmentWithName:(NSString *)name existsForDocumentWithId:(NSString *)identifier {
    if ((! name) || (! identifier)) {
        return NO;
    }
    
    __block BOOL result = NO;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?",
                           _solution, identifier, name];
        if (! rs) {
            return;
        }
        
        result = ([rs next]) && ([rs intForColumnIndex:0] == 1);
        [rs close];
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
    
    if (! [self documentExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT contentType FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?",
                           _solution, identifier, name];
        if (rs) {
            if ([rs next]) {
                result = @{kAIQAttachmentName: name, kAIQAttachmentContentType: [rs stringForColumnIndex:0]};
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
    
    if (! [self documentExistsWithId:identifier]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
        }
        return nil;
    }
    
    __block NSMutableArray *result = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT name, contentType FROM localattachments WHERE solution = ? AND identifier = ? ",
                           _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        result = [NSMutableArray array];
        while ([rs next]) {
            [result addObject:@{kAIQAttachmentName: [rs stringForColumnIndex:0], kAIQAttachmentContentType: [rs stringForColumnIndex:1]}];
        }
        [rs close];
    }];
    
    return result ? [result copy] : nil;
}

- (NSDictionary *)createAttachmentWithName:(NSString *)name
                               contentType:(NSString *)contentType
                                   andData:(NSData *)data
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

    if (! identifier) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Identifier not specified"];
        }
        return nil;
    }
    
    __block NSDictionary *result = nil;
    
    [_pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM localdocuments WHERE solution = ? AND identifier = ?",
                           _solution, identifier];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ((! [rs next]) || ([rs intForColumnIndex:0] != 1)) {
            [rs close];
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        
        [rs close];
        
        rs = [db executeQuery:@"SELECT COUNT(*) FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?", _solution, identifier, name];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if (([rs next]) && ([rs intForColumnIndex:0] != 0)) {
            [rs close];
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Duplicate attachment name"];
            }
            return;
        }
        [rs close];
        
        if (! [db executeUpdate:@"INSERT INTO localattachments (solution, identifier, name, contentType) VALUES (?, ?, ?, ?)",
               _solution, identifier, name, contentType]) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
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
        
        result = @{kAIQAttachmentName: name, kAIQAttachmentContentType: contentType};
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
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM localdocuments WHERE solution = ? AND identifier = ?",
                           _solution, identifier];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ((! [rs next]) || ([rs intForColumnIndex:0] != 1)) {
            [rs close];
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        
        [rs close];
        
        rs = [db executeQuery:@"SELECT COUNT(*) FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?",
              _solution, identifier, name];
        if (! rs) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ((! [rs next]) || ([rs intForColumnIndex:0] != 1)) {
            *rollback = YES;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
            return;
        }
        [rs close];
        
        if (! [db executeUpdate:@"UPDATE localattachments SET contentType = ? WHERE solution = ? AND identifier = ? AND name = ?",
               contentType, _solution, identifier, name]) {
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
        
        result = @{kAIQAttachmentName: name, kAIQAttachmentContentType: contentType};
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
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM localdocuments WHERE solution = ? AND identifier = ?",
                           _solution, identifier];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ((! [rs next]) || ([rs intForColumnIndex:0] != 1)) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorIdNotFound message:@"Document not found"];
            }
            return;
        }
        
        [rs close];
        
        rs = [db executeQuery:@"SELECT COUNT(*) FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?",
              _solution, identifier, name];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ((! [rs next]) || ([rs intForColumnIndex:0] != 1)) {
            [rs close];
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorNameNotFound message:@"Attachment not found"];
            }
            return;
        }
        
        [rs close];
        
        if (! [db executeUpdate:@"DELETE FROM localattachments WHERE solution = ? AND identifier = ? AND name = ?", _solution, identifier, name]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        [_fileManager removeItemAtPath:[[_basePath stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:name] error:nil];
        
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

@end
