#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQJSON.h"
#import "AIQLog.h"
#import "AIQSynchronization.h"
#import "DeleteOperation.h"
#import "common.h"

@interface DeleteOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, retain) NSMutableData *data;

@end

@implementation DeleteOperation

- (void)onStart {
    AIQLogCInfo(1, @"Deleting attachment %@ for document %@", self.attachmentName, self.type);
    
    __block NSError *error = nil;
    __block NSString *link;
    __block long long revision;
    
    FMDatabasePool *pool = [self pool];
    [pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT link, revision FROM attachments WHERE solution = ? AND identifier = ? AND name = ?",
                           self.solution, self.identifier, self.attachmentName];
        if (! rs) {
            error = [db lastError];
            return;
        }
        
        [rs next];
        
        link = [rs stringForColumnIndex:0];
        revision = [rs longLongIntForColumnIndex:1];
        [rs close];
    }];
    
    if (error) {
        AIQLogCError(1, @"Could not retrieve attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
        [self clean];
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:link]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:self.timeout];
    request.HTTPMethod = @"DELETE";
    [request setValue:[NSString stringWithFormat:@"BEARER %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:[NSString stringWithFormat:@"%lld", revision] forHTTPHeaderField:@"If-Match"];
    
    [self connectUsingRequest:request];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Attachment %@ for document %@ failed: %@", self.attachmentName, self.identifier, error.localizedDescription);
    [self clean];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    
    if (! [self processStatusCode:statusCode]) {
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
    
    [pool inDatabase:^(FMDatabase *db) {
        NSError *error = nil;
        
        if (statusCode == 200) {
            if (! [db executeUpdate:@"DELETE FROM attachments WHERE solution = ? AND identifier = ? AND name = ?", self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not remove attachment %@ for document %@: %@", self.attachmentName, self.identifier,error.localizedDescription);
                return;
            }
            
            NSString *path = [[[self.basePath stringByAppendingPathComponent:self.solution] stringByAppendingPathComponent:self.identifier] stringByAppendingPathComponent:self.name];
            if (! [[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
                AIQLogCError(1, @"Could not remove file of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                return;
            }
            
            NSString *string = httpResponse.allHeaderFields[@"X-AIQ-DocRev"];
            if (! string) {
                // XXX: WTF Apple, really!? This is due to the bug in iOS 4 which causes
                // the headers to be capitalized by the OS and not by the server
                string = httpResponse.allHeaderFields[@"X-Aiq-Docrev"];
            }
            if ([string hasPrefix:@"\""]) {
                string = [string substringWithRange:NSMakeRange(1, string.length - 2)];
            }
            long long revision = [string longLongValue];
            if (! [db executeUpdate:@"UPDATE documents SET revision = ? WHERE solution = ? AND identifier = ?", @(revision), self.solution, self.identifier]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not update revision for document %@: %@", self.identifier, error.localizedDescription);
                return;
            }
            
            AIQLogCInfo(1, @"Attachment %@ for document %@ deleted", self.attachmentName, self.identifier);
            [[self synchronizer] didSynchronizeAttachment:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
        } else if ((statusCode >= 400) && (statusCode < 500)) {
            AIQRejectionReason reason = [self reasonFromStatusCode:statusCode];
            if (! [db executeUpdate:@"UPDATE attachments SET status = ?, rejectionReason = ? WHERE solution = ? AND identifier = ? AND name = ?",
                   @(AIQSynchronizationStatusRejected), @(reason), self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not reject attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                return;
            }
            
            [[self synchronizer] didRejectAttachment:self.attachmentName identifier:self.identifier type:self.type solution:self.solution reason:reason];
        } else {
            AIQLogCWarn(1, @"Attachment %@ for document %@ temporarily failed to synchronize", self.attachmentName, self.identifier);
            [[self synchronizer]  attachmentError:self.attachmentName
                                       identifier:self.identifier
                                             type:self.type
                                         solution:self.solution
                                        errorCode:statusCode
                                           status:AIQSynchronizationStatusDeleted];
        }
    }];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSDictionary *response = [_data JSONObject];
    [self storeLinks:response[@"links"]];
    [self clean];
}

@end
