#import <FMDB/FMDB.h>

#import "AIQContext.h"
#import "AIQDataStore.h"
#import "AIQJSON.h"
#import "AIQLog.h"
#import "AIQMessaging.h"
#import "AIQMessagingSynchronizer.h"
#import "AIQSession.h"
#import "AIQSynchronization.h"
#import "NSDictionary+Helpers.h"
#import "NSURL+Helpers.h"
#import "SendMessageOperation.h"
#import "common.h"

@interface AIQMessagingSynchronizer ()

- (void)handleUnauthorized;
- (void)scheduleNextNotification;

@end

@interface SendMessageOperation () <NSURLConnectionDataDelegate> {
    NSURLConnection *_connection;
    NSInteger _statusCode;
    BOOL _expectResponse;
    NSString *_destination;
    FMDatabaseQueue *_queue;
}

@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isCancelled;

@end

@implementation SendMessageOperation

- (id)init {
    self = [super init];
    if (self) {
        _thread = [NSThread currentThread];
    }
    return self;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return YES;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    if (! [[NSThread currentThread] isEqual:_thread]) {
        [self performSelector:@selector(start) onThread:_thread withObject:nil waitUntilDone:YES];
        return;
    }
    
    if ([self isCancelled]) {
        return;
    }
    
    [self setIsExecuting:YES];
    
    AIQContext *context = [_synchronizer valueForKey:@"context"];
    AIQSession *session = [_synchronizer valueForKey:@"session"];
    
    _queue = [FMDatabaseQueue databaseQueueWithPath:[session valueForKey:@"dbPath"]];
    
    __block BOOL shouldClean = NO;
    
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT destination, payload, created, launchable, expectResponse FROM comessages "
                           "WHERE solution = ? AND identifier = ?",
                           _solution, _identifier];
        if (! rs) {
            AIQLogCError(1, @"Could not retrieve message %@: %@", _identifier, [db lastError].localizedDescription);
            shouldClean = YES;
            return;
        }
        
        if (! [rs next]) {
            AIQLogCError(1, @"Could not find message %@", _identifier);
            shouldClean = YES;
            return;
        }
        
        NSData *payload = [rs dataForColumnIndex:1];
        NSString *launchable = [rs stringForColumnIndex:3];
        NSNumber *created = [rs objectForColumnIndex:2];
        
        _destination = [rs stringForColumnIndex:0];
        _expectResponse = [rs boolForColumnIndex:4];
        
        AIQLogCInfo(1, @"Sending message %@ to %@", _identifier, _destination);
        
        [rs close];
        
        NSURL *url = [NSURL URLWithString:[session propertyForName:@"comessage"]];
        NSMutableDictionary *query = [url.queryAsDictionary mutableCopy];
        query[@"_solution"] = _solution;
        query[@"_destination"] = _destination;
        
        NSString *link = [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];
        if (url.port) {
            link = [link stringByAppendingFormat:@":%d", url.port.intValue];
        }
        if (url.path) {
            link = [link stringByAppendingString:url.path];
        }
        link = [link stringByAppendingFormat:@"?%@", [query asQuery]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:link]
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                           timeoutInterval:_timeout];
        request.HTTPMethod = @"POST";
        [request setValue:@"multipart/form-data; boundary=\"b357b0und4ry3v3r\"" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"BEARER %@", [session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];
        [request setValue:_identifier forHTTPHeaderField:@"X-AIQ-MessageId"];
        [request setValue:[NSString stringWithFormat:@"%@", created] forHTTPHeaderField:@"X-AIQ-Created"];
        
        [request setValue:(_expectResponse ? @"true" : @"false") forHTTPHeaderField:@"X-AIQ-Expect-Response"];
        [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
        if (launchable) {
            [request setValue:launchable forHTTPHeaderField:@"X-AIQ-Launchable"];
        }
        NSMutableData *body = [NSMutableData data];
        [body appendData:[@"--b357b0und4ry3v3r\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"_payload\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/json\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:payload];
        [body appendData:[@"\r\n--b357b0und4ry3v3r\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"_context\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/json\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSMutableDictionary *contextData = [NSMutableDictionary dictionary];
        id value = context ? [context valueForName:@"com.appearnetworks.aiq.location" error:nil] : nil;
        if (! value) {
            value = @{};
        }
        [contextData setValue:value forKey:@"com.appearnetworks.aiq.location"];
        value = context ? [context valueForName:@"com.appearnetworks.aiq.apps" error:nil] : nil;
        if (! value) {
            value = @{};
        }
        [contextData setValue:value forKey:@"com.appearnetworks.aiq.apps"];
        [body appendData:[contextData JSONData]];
        
        rs = [db executeQuery:@"SELECT name, contentType, link FROM coattachments WHERE solution = ? AND identifier = ?",
              _solution, _identifier];
        if (! rs) {
            AIQLogCError(1, @"Could not retrieve attachments for message %@: %@", _identifier, [db lastError].localizedDescription);
            shouldClean = YES;
            return;
        }
        
        while ([rs next]) {
            if ([self isCancelled]) {
                shouldClean = YES;
                return;
            }
            
            NSString *name = [rs stringForColumnIndex:0];
            NSString *contentType = [rs stringForColumnIndex:1];
            NSString *attachmentUrl = [rs stringForColumnIndex:2];
            
            AIQLogCInfo(1, @"Adding attachment %@ to message %@", name, _identifier);
            
            NSURL *attachmentURL;
            if ([attachmentUrl rangeOfString:@"://"].location == NSNotFound) {
                // file URL
                attachmentURL = [NSURL fileURLWithPath:attachmentUrl];
            } else {
                attachmentURL = [NSURL URLWithString:attachmentUrl];
            }
            
            NSError *error = nil;
            NSData *attachmentData = [NSData dataWithContentsOfURL:attachmentURL options:NSDataReadingUncached error:&error];
            if (! attachmentData) {
                if (! [db executeUpdate:@"UPDATE comessages SET state = ?, response = ?, responseId = ? WHERE solution = ? AND identifier = ?",
                       @(AIQMessageStateRejected), error.localizedDescription, nil, _solution, _identifier]) {
                    AIQLogCError(1, @"Could not update the state of message %@: %@", _identifier, [db lastError].localizedDescription);
                }
                NOTIFY(AIQDidRejectMessageNotification, _synchronizer, (@{AIQDocumentIdUserInfoKey: _identifier,
                                                                          AIQSolutionUserInfoKey: _solution,
                                                                          AIQMessageDestinationUserInfoKey: _destination}));
                shouldClean = YES;
                return;
            }
            [body appendData:[@"\r\n--b357b0und4ry3v3r\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", name] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", contentType] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:attachmentData];
        }
        [rs close];
        
        [body appendData:[@"\r\n--b357b0und4ry3v3r--\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        request.HTTPBody = body;
        
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_connection start];
    }];
    
    if (shouldClean) {
        [self clean];
    }
}

- (void)cancel {
    if (! [[NSThread currentThread] isEqual:_thread]) {
        [self performSelector:@selector(cancel) onThread:_thread withObject:nil waitUntilDone:YES];
        return;
    }
    
    AIQLogCInfo(1, @"Cancelling message %@", _identifier);
    
    [self setIsCancelled:YES];
    
    if (_connection) {
        [_connection cancel];
    }
    
    [self clean];
}

- (BOOL)isEqual:(id)object {
    if (! [object isKindOfClass:[SendMessageOperation class]]) {
        return NO;
    }
    return [((SendMessageOperation *)object).identifier isEqualToString:_identifier];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Message %@ failed: %@", _identifier, error.localizedDescription);
    [self clean];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _statusCode = httpResponse.statusCode;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (_statusCode == 202) {
        AIQLogCInfo(1, @"Message %@ has been accepted", _identifier);
        [_queue inDatabase:^(FMDatabase *db) {
            if (_expectResponse) {
                AIQLogCInfo(1, @"Message %@ expects a response, keeping the status", _identifier);
                if (! [db executeUpdate:@"UPDATE comessages SET state = ?, response = ?, responseId = ? WHERE solution = ? AND identifier = ?",
                       @(AIQMessageStateAccepted), nil, nil, _solution, _identifier]) {
                    AIQLogCError(1, @"Could not update the state of message %@: %@", _identifier, [db lastError].localizedDescription);
                }
            } else {
                AIQLogCInfo(1, @"Message %@ does not expect a response, removing the status", _identifier);
                
                if (! [db executeUpdate:@"DELETE FROM comessages WHERE solution = ? AND identifier = ?", _solution, _identifier]) {
                    AIQLogCError(1, @"Could not delete message %@: %@", _identifier, [db lastError].localizedDescription);
                }
            }
            
            if (! [db executeUpdate:@"DELETE FROM coattachments WHERE solution = ? AND identifier = ?", _solution, _identifier]) {
                AIQLogCError(1, @"Could not delete attachments of message %@: %@", _identifier, [db lastError].localizedDescription);
            }
            
            NOTIFY(AIQDidAcceptMessageNotification, _synchronizer, (@{AIQDocumentIdUserInfoKey: _identifier,
                                                                      AIQSolutionUserInfoKey: _solution,
                                                                      AIQMessageDestinationUserInfoKey: _destination}));
        }];
    } else if (_statusCode == 401) {
        [connection cancel];
        [connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_queue close];
        [_synchronizer handleUnauthorized];
    } else if (_statusCode == 503) {
        AIQLogCWarn(1, @"Mobility platform unavailable for message %@", _identifier);
    } else {
        AIQLogCInfo(1, @"Message %@ has been rejected: %ld", _identifier, (long)_statusCode);
        NSString *cause = nil;
        if (_statusCode == 400) {
            cause = @"Malformed message";
        } else if (_statusCode == 403) {
            cause = @"Permission denied";
        } else if (_statusCode == 404) {
            cause = @"Invalid destination";
        } else if (_statusCode == 413) {
            cause = @"Message too big";
        }

        [_queue inDatabase:^(FMDatabase *db) {
            if (! [db executeUpdate:@"UPDATE comessages SET state = ?, response = ?, responseId = ? WHERE solution = ? AND identifier = ?",
                   @(AIQMessageStateRejected), cause, nil, _solution, _identifier]) {
                AIQLogCError(1, @"Could not update the state of message %@: %@", _identifier, [db lastError].localizedDescription);
            }
            
            if (! [db executeUpdate:@"DELETE FROM coattachments WHERE solution = ? AND identifier = ?", _solution, _identifier]) {
                AIQLogCError(1, @"Could not delete attachments of message %@: %@", _identifier, [db lastError].localizedDescription);
            }
            
            if (! _expectResponse) {
                long long timestamp = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
                if (! [db executeUpdate:@"INSERT OR REPLACE INTO somessages (solution, identifier, type, revision, created, activeFrom, timeToLive, read)"
                       "VALUES (?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT read FROM somessages WHERE identifier = ?), 0))",
                       _solution, _identifier, @"_comessageresponse", @(timestamp), @(timestamp), @3600, @NO]) {
                    AIQLogCError(1, @"Could not create a stub response for message %@: %@", _identifier, [db lastError].localizedDescription);
                }
                [_synchronizer scheduleNextNotification];
            }
        }];
        
        NOTIFY(AIQDidRejectMessageNotification, _synchronizer, (@{AIQDocumentIdUserInfoKey: _identifier,
                                                                  AIQSolutionUserInfoKey: _solution,
                                                                  AIQMessageDestinationUserInfoKey: _destination}));
    }
    
    [self clean];
}

#pragma mark - Private API

- (void)clean {
    if (_connection) {
        [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _connection = nil;
    }
    
    if (_queue) {
        [_queue close];
        _queue = nil;
    }
    
    if (_isExecuting) {
        [self setIsExecuting:NO];
    }
    if (! _isFinished) {
        [self setIsFinished:YES];
    }
}

@end
