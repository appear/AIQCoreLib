#import "AIQContext.h"
#import "AIQContextSynchronizer.h"
#import "AIQSession.h"
#import "FMDB.h"
#import "common.h"

@interface AIQContextSynchronizer () {
    FMDatabasePool *_pool;
}

@end

@implementation AIQContextSynchronizer

- (instancetype)initForSession:(AIQSession *)session {
    self = [super init];
    if (self) {
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
    }
    return self;
}

- (void)didCreateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE type = '_backendcontext'"];
        if (! rs) {
            return;
        }
        
        if ([rs next]) {
            NSDictionary *context = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:0] options:kNilOptions error:nil];
            for (NSString *key in context) {
                NOTIFY(AIQDidChangeContextValue, self, (@{AIQContextNameUserInfoKey: key, AIQContextValueUserInfoKey: context[key]}));
            }
        }
        
        [rs close];
    }];
}

- (void)didUpdateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data FROM documents WHERE type = '_backendcontext'"];
        if (! rs) {
            return;
        }
        
        if ([rs next]) {
            NSDictionary *context = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:0] options:kNilOptions error:nil];
            for (NSString *key in context) {
                NOTIFY(AIQDidChangeContextValue, self, (@{AIQContextNameUserInfoKey: key, AIQContextValueUserInfoKey: context[key]}));
            }
        }
        
        [rs close];
    }];
}

- (void)didDeleteDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
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
    
}

- (void)attachmentDidBecomeUnavailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)attachmentDidFail:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution {
    
}

- (void)attachmentDidProgress:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution progress:(float)progress {
    
}

- (void)close {
    
}

@end
