#import "AIQContext.h"
#import "AIQDataStore.h"
#import "AIQError.h"
#import "AIQLocationContextProvider.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "DeviceContextProvider.h"
#import "FMDB.h"
#import "common.h"

NSString *const AIQDidChangeContextValue = @"AIQDidChangeContextValue";
NSString *const AIQContextNameUserInfoKey = @"AIQContextNameUserInfoKey";
NSString *const AIQContextValueUserInfoKey = @"AIQContextValueUserInfoKey";

@interface AIQContext () {
    NSSet *_standardContextProviders;
    AIQSession *_session;
    FMDatabasePool *_pool;
}

@end

@implementation AIQContext

- (instancetype)initForSession:(AIQSession *)session error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    self = [super init];
    if (self) {
        _pool = [FMDatabasePool databasePoolWithPath:[session valueForKey:@"dbPath"]];
        
        _standardContextProviders = [NSSet setWithObjects:[DeviceContextProvider new], [AIQLocationContextProvider new], nil];
        NSMutableDictionary *document = [self clientContextDocument:error];
        if (! document) {
            return nil;
        }
        
        AIQLogCInfo(1, @"Updating client context");
        NSString *identifier = document[kAIQDocumentId];
        [document removeAllObjects];
        document[kAIQDocumentId] = identifier;
        for (id contextProvider in _standardContextProviders) {
            NSString *name = [contextProvider valueForKey:@"name"];
            id data = [contextProvider valueForKey:@"data"];
            if (data) {
                document[name] = data;
                NOTIFY(AIQDidChangeContextValue, self, (@{AIQContextNameUserInfoKey: name, AIQContextValueUserInfoKey: data}));
            }
            [contextProvider addObserver:self forKeyPath:@"data" options:NSKeyValueObservingOptionNew context:nil];
        }
        if (! [self updateClientContext:document error:error]) {
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc {
    [self close];
}

- (void)close {
    if (_contextProviders) {
        for (id contextProvider in _contextProviders) {
            [contextProvider removeObserver:self forKeyPath:@"data"];
        }
    }
}

- (void)setContextProviders:(NSSet *)contextProviders {
    NSError *error = nil;
    NSMutableDictionary *document = [self clientContextDocument:&error];
    if (document) {
        if (_contextProviders) {
            for (id contextProvider in _contextProviders) {
                [document removeObjectForKey:[contextProvider valueForKey:@"name"]];
            }
        }
        if ((contextProviders) && (contextProviders.count != 0)) {
            for (id contextProvider in contextProviders) {
                NSString *name = [contextProvider valueForKey:@"name"];
                if (! [self isStandardContextProvider:name]) {
                    id data = [contextProvider valueForKey:@"data"];
                    if (data) {
                        document[name] = data;
                        NOTIFY(AIQDidChangeContextValue, self, (@{AIQContextNameUserInfoKey: name, AIQContextValueUserInfoKey: data}));
                    }
                    [contextProvider addObserver:self forKeyPath:@"data" options:NSKeyValueObservingOptionNew context:nil];
                }
            }
            [self updateClientContext:document error:nil];
        }
        _contextProviders = contextProviders;
    } else {
        AIQLogCError(1, @"Error getting client context: %@", error.localizedDescription);
    }
}

- (id)valueForName:(NSString *)name error:(NSError *__autoreleasing *)error {
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return nil;
    }
    if ([name hasPrefix:@"_"]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Restricted provider name"];
        }
        return nil;
    }
    id value = nil;
    
    NSDictionary *document = [self clientContextDocument:error];
    if (document) {
        value = document[name];
    }
    document = [self backendContextDocument:error];
    if (value) {
        if (document[name]) {
            AIQLogCWarn(1, @"Duplicated provider in client context: %@", name);
        }
    } else {
        if (document) {
            value = document[name];
        }
    }
    
    if ((! value) && (error)) {
        *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Context not found"];
    }
    
    return value;
}

- (BOOL)setValue:(id)value
         forName:(NSString *)name
           error:(NSError *__autoreleasing *)error {
    if (! name) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Name not specified"];
        }
        return NO;
    }
    if ([name hasPrefix:@"_"]) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Restricted provider name"];
        }
        return NO;
    }
    
    NSMutableDictionary *document = [self clientContextDocument:error];
    if (! document) {
        return NO;
    }
    
    AIQLogCInfo(1, @"Will set value %@ for context key %@", value, name);
    
    document[name] = value ? value : [NSNull null];
    if ([self updateClientContext:document error:error]) {
        NOTIFY(AIQDidChangeContextValue, self, (@{AIQContextNameUserInfoKey: name, AIQContextValueUserInfoKey: value}));
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)names:(void (^)(NSString *, NSError *__autoreleasing *))processor error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! processor) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Processor not specified"];
        }
        return NO;
    }
    
    NSDictionary *context = [self backendContextDocument:error];
    if (! context) {
        return NO;
    }
    
    NSError *localError = nil;
    for (NSString *key in context) {
        if ([key characterAtIndex:0] != '_') {
            processor(key, &localError);
            if (localError) {
                if (error) {
                    *error = localError;
                }
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark - Private API

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    NSString *key = [object valueForKey:@"name"];
    NSObject *value = change[NSKeyValueChangeNewKey];
    NSError *error = nil;
    NSMutableDictionary *document = [self clientContextDocument:&error];
    if (! document) {
        return;
    }
    
    [self willChangeValueForKey:key];
    AIQLogCInfo(1, @"Value for provider %@ changed to %@", key, value);
    document[key] = value;
    if ([self updateClientContext:document error:&error]) {
        [self didChangeValueForKey:key];
    } else {
        AIQLogCError(1, @"Error getting client context: %@", error.localizedDescription);
    }
}

- (BOOL)updateClientContext:(NSDictionary *)context error:(NSError *__autoreleasing *)error {
    __block BOOL result = NO;
    
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    for (NSString *field in context) {
        if ([field characterAtIndex:0] != '_') {
            fields[field] = context[field];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:fields options:kNilOptions error:nil];
    
    [_pool inDatabase:^(FMDatabase *db) {
        if (! [db executeUpdate:@"UPDATE documents SET status = ?, data = ?, rejectionReason = NULL WHERE solution = '_global' AND identifier = ?",
             @(AIQSynchronizationStatusUpdated), data, context[kAIQDocumentId]]) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        result = YES;
    }];
    
    return result;
}

- (NSMutableDictionary *)clientContextDocument:(NSError *__autoreleasing *)error {
    __block NSMutableDictionary *document = nil;
    
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT data, identifier FROM documents WHERE solution = '_global' AND type = '_clientcontext'"];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ([rs next]) {
            document = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:0] options:NSJSONReadingMutableContainers error:nil];
            document[kAIQDocumentId] = [rs stringForColumnIndex:1];
        } else {
            NSString *identifier = [[NSUUID UUID] UUIDString];
            document = [NSMutableDictionary dictionaryWithCapacity:_standardContextProviders.count];
            for (id contextProvider in _standardContextProviders) {
                id value = [contextProvider valueForKey:@"data"];
                if (value) {
                    document[[contextProvider valueForKey:@"name"]] = value;
                }
            }
            NSData *data = [NSJSONSerialization dataWithJSONObject:document options:kNilOptions error:nil];
            
            if (! [db executeUpdate:@"INSERT INTO documents (solution, identifier, type, status, data) VALUES (?, ?, ?, ?, ?)",
                   @"_global", identifier, @"_clientcontext", @(AIQSynchronizationStatusCreated), data]) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
                }
            }
            
            document[kAIQDocumentId] = identifier;
        }
        
        [rs close];
    }];
    
    return document;
}

- (NSDictionary *)backendContextDocument:(NSError *__autoreleasing *)error {
    __block NSMutableDictionary *document = nil;
    [_pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT identifier, data FROM documents WHERE type = '_backendcontext'"];
        if (! rs) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:[db lastError].localizedDescription];
            }
            return;
        }
        
        if ([rs next]) {
            document = [NSJSONSerialization JSONObjectWithData:[rs dataForColumnIndex:1] options:NSJSONReadingMutableContainers error:nil];
            document[kAIQDocumentId] = [rs stringForColumnIndex:0];
        }
        
        [rs close];
    }];
    
    return document;
}

- (BOOL)isStandardContextProvider:(NSString *)name {
    BOOL standard = NO;
    for (id contextProvider in _standardContextProviders) {
        NSString *standardName = [contextProvider valueForKey:@"name"];
        if ([standardName isEqualToString:name]) {
            standard = YES;
            break;
        }
    }
    return standard;
}

@end
