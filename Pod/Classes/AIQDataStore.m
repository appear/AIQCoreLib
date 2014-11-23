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
NSString *const kAIQAttachmentResourceUrl = @"AIQAttachmentResourceUrl";
NSString *const kAIQAttachmentSynchronizationStatus = @"AIQAttachmentSynchronizationStatus";
NSString *const kAIQAttachmentState = @"AIQAttachmentState";

@interface AIQDataStore () {
    FMDatabasePool *_pool;
    NSString *_solution;
}

@end

@implementation AIQDataStore

- (instancetype)init {
    return nil;
}

- (instancetype)initForSession:(AIQSession *)session solution:(NSString *)solution {
    self = [super init];
    if (self) {
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
        _solution = solution;
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

@end
