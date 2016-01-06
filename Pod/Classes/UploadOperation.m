#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQJSON.h"
#import "AIQLog.h"
#import "AIQSynchronization.h"
#import "NSDictionary+Helpers.h"
#import "NSURL+Helpers.h"
#import "UploadOperation.h"
#import "common.h"

@interface UploadOperation () <NSURLConnectionDataDelegate> {
    NSMutableData *_data;
    NSInteger _statusCode;
    BOOL _exists;
}

@end

@implementation UploadOperation

- (void)onStart {
    AIQLogCInfo(1, @"Uploading attachment %@ for document %@", self.attachmentName, self.type);
    
    __block NSError *error = nil;
    __block NSString *link;
    __block long long revision;
    __block NSString *contentType;
    
    FMDatabasePool *pool = [self pool];
    [pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT link, revision, contentType FROM attachments WHERE solution = ? AND identifier = ? AND name = ?",
                           self.solution, self.identifier, self.attachmentName];
        if (! rs) {
            error = [db lastError];
            return;
        }
        
        [rs next];
        
        link = [rs stringForColumnIndex:0];
        revision = [rs longLongIntForColumnIndex:1];
        contentType = [rs stringForColumnIndex:2];
        
        [rs close];
    }];
    
    if (error) {
        AIQLogCError(1, @"Could not retrieve attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
        [self clean];
        return;
    }
    
    if (! link) {
        // initial insert, link needs to be generated
        NSURL *url = [NSURL URLWithString:[self sessionPropertyWithName:@"attachments"]];
        NSMutableDictionary *query = [url.queryAsDictionary mutableCopy];
        query[@"docId"] = self.identifier;
        query[@"docType"] = self.type;
        query[@"solution"] = self.solution;
        link = [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];
        if (url.port) {
            link = [link stringByAppendingFormat:@":%d", url.port.intValue];
        }
        if (url.path) {
            link = [link stringByAppendingString:url.path];
        }
        link = [link stringByAppendingFormat:@"?%@", [query asQuery]];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:link]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:self.timeout];
    if (revision == 0l) {
        _exists = NO;
        request.HTTPMethod = @"POST";
        [request setValue:self.attachmentName forHTTPHeaderField:@"Slug"];
    } else {
        _exists = YES;
        request.HTTPMethod = @"PUT";
        [request setValue:[NSString stringWithFormat:@"%lld", revision] forHTTPHeaderField:@"If-Match"];
    }
    [request setValue:[NSString stringWithFormat:@"BEARER %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    NSString *path = [[[self.basePath stringByAppendingPathComponent:self.solution] stringByAppendingPathComponent:self.identifier] stringByAppendingPathComponent:self.attachmentName];
    request.HTTPBody = [[NSFileManager defaultManager] contentsAtPath:path];
    
    [self connectUsingRequest:request];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Attachment %@ for document %@ failed: %@", self.attachmentName, self.identifier, error.localizedDescription);
    [self clean];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _statusCode = httpResponse.statusCode;
    
    if (! [self processStatusCode:_statusCode]) {
        [connection cancel];
        [self clean];
        return;
    }
    
    if (httpResponse.expectedContentLength == -1) {
        _data = [NSMutableData data];
    } else {
        _data = [NSMutableData dataWithCapacity:(NSUInteger)httpResponse.expectedContentLength];
    }
    
    FMDatabasePool *pool = [self pool];
    __block BOOL shouldClean = NO;
    [pool inDatabase:^(FMDatabase *db) {
        NSError *error = nil;
        
        if ((_statusCode == 200) || (_statusCode == 201)) {
            NSString *string = httpResponse.allHeaderFields[@"ETag"];
            if ([string hasPrefix:@"\""]) {
                string = [string substringWithRange:NSMakeRange(1, string.length - 2)];
            }
            long long revision = [string longLongValue];
            NSString *link = httpResponse.allHeaderFields[@"Location"];
            
            if (! [db executeUpdate:@"UPDATE attachments SET revision = ?, link = ?, status = ? WHERE solution = ? AND identifier = ? AND name = ?",
                   @(revision), link, @(AIQSynchronizationStatusSynchronized), self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not update revision of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                [connection cancel];
                shouldClean = YES;
                return;
            }
            
            string = httpResponse.allHeaderFields[@"X-AIQ-DocRev"];
            if (! string) {
                // XXX: WTF Apple, really!? This is due to the bug in iOS 4 which causes
                // the headers to be capitalized by the OS and not by the server
                string = httpResponse.allHeaderFields[@"X-Aiq-Docrev"];
            }
            if ([string hasPrefix:@"\""]) {
                string = [string substringWithRange:NSMakeRange(1, string.length - 2)];
            }
            revision = [string longLongValue];
            if (! [db executeUpdate:@"UPDATE documents SET revision = ? WHERE solution = ? AND identifier = ?", @(revision), self.solution, self.identifier]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not update revision for document %@: %@", self.identifier, error.localizedDescription);
                [connection cancel];
                shouldClean = YES;
                return;
            }
            
            AIQLogCInfo(1, @"Attachment %@ for document %@ uploaded", self.attachmentName, self.identifier);
            [[self synchronizer] didSynchronizeAttachment:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
        } else if ((_statusCode >= 400) && (_statusCode < 500)) {
            AIQRejectionReason reason = [self reasonFromStatusCode:_statusCode];
            if (! [db executeUpdate:@"UPDATE attachments SET status = ?, rejectionReason = ? WHERE solution = ? AND identifier = ? AND name = ?",
                   @(AIQSynchronizationStatusRejected), @(reason), self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not reject attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                [connection cancel];
                shouldClean = YES;
                return;
            }
            
            [[self synchronizer] didRejectAttachment:self.attachmentName identifier:self.identifier type:self.type solution:self.solution reason:reason];
        } else {
            AIQLogCWarn(1, @"Attachment %@ for document %@ temporarily failed to synchronize", self.attachmentName, self.identifier);
            [[self synchronizer] attachmentError:self.attachmentName
                                      identifier:self.identifier
                                            type:self.type
                                        solution:self.solution
                                       errorCode:_statusCode
                                          status:_exists ? AIQSynchronizationStatusUpdated : AIQSynchronizationStatusCreated];
        }
    }];
    
    if (shouldClean) {
        [self clean];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if ((_statusCode == 200) || (_statusCode == 201)) {
        NSDictionary *response = [_data JSONObject];
        [self storeLinks:response[@"links"]];
    }
    [self clean];
}

@end
