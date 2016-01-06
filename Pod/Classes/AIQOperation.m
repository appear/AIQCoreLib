#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQLog.h"
#import "AIQOperation.h"
#import "AIQSession.h"

@interface AIQSession ()

- (void)synchronizeProperties;

@end

@interface AIQSynchronization ()

- (void)handleUnauthorized;
- (void)handleGone;
- (id<AIQSynchronizer>)synchronizerForType:(NSString *)type;

@end

@interface AIQOperation () {
    NSURLConnection *_connection;
    FMDatabasePool *_pool;
    NSPort *_port;
}


@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isCancelled;

@end

@implementation AIQOperation

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return YES;
}

- (BOOL)isConcurrent {
    return NO;
}

- (void)onStart {
    // do nothing
}

- (void)start {
    if ([self isCancelled]) {
        return;
    }
    
    [self setIsExecuting:YES];
    
    [self onStart];
}

- (void)cancel {
    AIQLogCInfo(1, @"Cancelling attachment %@ for document %@", _attachmentName, _identifier);
    
    [self setIsCancelled:YES];
    
    if (_connection) {
        [_connection cancel];
    }
    
    [self clean];
}

- (void)connectUsingRequest:(NSURLRequest *)request {
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    _port = [NSPort port];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addPort:_port forMode:NSDefaultRunLoopMode];
    [_connection scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [_connection start];
    [runLoop run];
}

- (void)clean {
    if (_connection) {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [_connection unscheduleFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [runLoop removePort:_port forMode:NSDefaultRunLoopMode];
        _connection = nil;
    }
    
    _pool = nil;
    
    if (_isExecuting) {
        [self setIsExecuting:NO];
    }
    if (! _isFinished) {
        [self setIsFinished:YES];
    }
}

- (FMDatabasePool *)pool {
    if (! _pool) {
        _pool = [FMDatabasePool databasePoolWithPath:[[_synchronization valueForKey:@"session"] valueForKey:@"dbPath"]];
    }
    return _pool;
}

- (NSString *)accessToken {
    return [[_synchronization valueForKey:@"session"] valueForKey:@"session"][@"accessToken"];
}

- (NSString *)basePath {
    return [[_synchronization valueForKey:@"session"] valueForKey:@"basePath"];
}

- (id)sessionPropertyWithName:(NSString *)name {
    AIQSession *session = [_synchronization valueForKey:@"session"];
    return [session propertyForName:name];
}

- (void)storeLinks:(NSDictionary *)links {
    AIQSession *session = [_synchronization valueForKey:@"session"];
    if (links[@"nextDownload"]) {
        [session setProperty:links[@"nextDownload"] forName:@"download"];
    }
    if (links[@"nextUpload"]) {
        [session setProperty:links[@"nextUpload"] forName:@"upload"];
    }
    if (links[@"nextPending"]) {
        [session setProperty:links[@"nextPending"] forName:@"pending"];
    }
    if (links[@"nextAttachments"]) {
        [session setProperty:links[@"nextAttachments"] forName:@"attachments"];
    }
    if (links[@"nextPush"]) {
        [session setProperty:links[@"nextPush"] forName:@"push"];
    }
}

- (BOOL)processStatusCode:(NSInteger)statusCode {
    if (statusCode == 401) {
        [_synchronization handleUnauthorized];
        return NO;
    }
    
    if (statusCode == 410) {
        [_synchronization handleGone];
        return NO;
    }
    
    return YES;
}

- (AIQRejectionReason)reasonFromStatusCode:(NSInteger)statusCode {
    AIQRejectionReason reason = AIQRejectionReasonUnknown;
    if (statusCode == 403) {
        AIQLogCInfo(1, @"Permission denied for attachment %@ in document %@", self.attachmentName, self.identifier);
        reason = AIQRejectionReasonPermissionDenied;
    } else if (statusCode == 404) {
        AIQLogCInfo(1, @"Document %@ not found", self.identifier);
        reason = AIQRejectionReasonDocumentNotFound;
    } else if (statusCode == 405) {
        AIQLogCInfo(1, @"Operation not allowed for attachment %@ in document  %@", self.attachmentName, self.identifier);
        reason = AIQRejectionReasonTypeNotFound;
    } else if (statusCode == 409) {
        AIQLogCInfo(1, @"Attachment %@ already exists in document %@", self.attachmentName, self.identifier);
        reason = AIQRejectionReasonCreateConflict;
    } else if (statusCode == 412) {
        AIQLogCInfo(1, @"Revision conflict for attachment %@ in document %@", self.attachmentName, self.identifier);
        reason = AIQRejectionReasonUpdateConflict;
    } else if (statusCode == 413) {
        AIQLogCInfo(1, @"Attachment %@ in document %@ is too big", self.attachmentName, self.identifier);
        reason = AIQRejectionReasonLargeAttachment;
    }
    return reason;
}

- (id<AIQSynchronizer>)synchronizer {
    return [_synchronization synchronizerForType:self.type];
}

@end
