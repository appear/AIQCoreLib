#import <FMDB/FMDB.h>

#import "AIQDataStore.h"
#import "AIQLog.h"
#import "AIQSynchronization.h"
#import "DownloadOperation.h"
#import "common.h"

@interface DownloadOperation () <NSURLConnectionDataDelegate> {
    long long _revision;
    long long _newRevision;
    NSFileHandle *_handle;
    NSInteger _statusCode;
    long long _currentLength;
    long long _contentLength;
}

@end

@implementation DownloadOperation

- (BOOL)isConcurrent {
    return YES;
}

- (void)onStart {
    AIQLogCInfo(1, @"Downloading attachment %@ for document %@", self.attachmentName, self.identifier);
    
    __block NSError *error = nil;
    __block NSString *link;
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
        
        _revision = [rs longLongIntForColumnIndex:1];
        _newRevision = _revision;
        
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
    request.HTTPMethod = @"GET";
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *folder = [[self.basePath stringByAppendingPathComponent:self.solution] stringByAppendingPathComponent:self.identifier];
    if (! [fileManager fileExistsAtPath:folder]) {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFileProtectionKey: NSFileProtectionComplete} error:nil];
    }
    
    NSString *path = [[folder stringByAppendingPathComponent:self.attachmentName] stringByAppendingPathExtension:@"tmp"];
    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (! attributes) {
            AIQLogCError(1, @"Could not retrieve file size: %@", error.localizedDescription);
            [self clean];
            return;
        }
        
        _currentLength = [attributes fileSize];
        AIQLogCInfo(1, @"%lld bytes of attachment %@ exist for document %@", _currentLength, self.attachmentName, self.identifier);
        [request setValue:[NSString stringWithFormat:@"bytes=%lld-", _currentLength] forHTTPHeaderField:@"Range"];
        [request setValue:[NSString stringWithFormat:@"%lld", _revision] forHTTPHeaderField:@"If-Range"];
    } else {
        if (! [fileManager createFileAtPath:path contents:nil attributes:@{NSFileProtectionKey: NSFileProtectionComplete}]) {
            AIQLogCError(1, @"Could not create file of attachment %@ for document %@", self.attachmentName, self.identifier);
            [self clean];
            return;
        }
        _currentLength = 0l;
    }
    
    if ([self isCancelled]) {
        return;
    }
    
    [[self synchronizer] willDownloadAttachment:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
    
    [self connectUsingRequest:request];
}

- (BOOL)isEqual:(id)object {
    if (! [object isKindOfClass:[DownloadOperation class]]) {
        return NO;
    }
    DownloadOperation *operation = (DownloadOperation *)object;
    return ([operation.solution isEqualToString:self.solution]) && ([operation.identifier isEqualToString:self.identifier]) && ([operation.attachmentName isEqualToString:self.attachmentName]);
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Attachment %@ for document %@ failed: %@", self.attachmentName, self.identifier, error.localizedDescription);
    [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
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
    
    _contentLength = httpResponse.expectedContentLength;
    
    if (httpResponse.allHeaderFields[@"ETag"]) {
        NSString *etag = httpResponse.allHeaderFields[@"ETag"];
        if ([etag hasPrefix:@"\""]) {
            etag = [etag substringWithRange:NSMakeRange(1, etag.length - 2)];
        }
        _newRevision = [etag longLongValue];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if ((_statusCode != 200) && (_statusCode != 206)) {
        return;
    }
    
    if (! _handle) {
        NSString *path = [[[[self.basePath stringByAppendingPathComponent:self.solution]
                            stringByAppendingPathComponent:self.identifier]
                           stringByAppendingPathComponent:self.attachmentName]
                          stringByAppendingPathExtension:@"tmp"];
        _handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (_statusCode == 206) {
            AIQLogCInfo(1, @"Ranges supported, resuming attachment %@ for document %@", self.attachmentName, self.identifier);
            [_handle seekToEndOfFile];
            _contentLength += _currentLength;
        } else {
            [_handle truncateFileAtOffset:0l];
            _currentLength = 0l;
        }
    }
    [_handle writeData:data];
    [_handle synchronizeFile];
    _currentLength += data.length;
    
    [[self synchronizer] attachmentDidProgress:self.attachmentName
                                    identifier:self.identifier
                                          type:self.type
                                      solution:self.solution
                                      progress:(float)_currentLength / (float)_contentLength];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    FMDatabasePool *pool = [self pool];
    [pool inDatabase:^(FMDatabase *db) {
        NSError *error = nil;
        if (_newRevision != _revision) {
            AIQLogCInfo(1, @"New revision %lld of attachment %@ for document %@", _newRevision, self.attachmentName, self.identifier);
            if (! [db executeUpdate:@"UPDATE attachments SET revision = ? WHERE solution = ? AND identifier = ? AND name = ?", @(_newRevision), self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not update revision of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
                return;
            }
        }
        
        if (((_statusCode == 200) || (_statusCode == 206)) && (_currentLength == _contentLength)) {
            // everything's ok
            NSString *path = [[[self.basePath stringByAppendingPathComponent:self.solution] stringByAppendingPathComponent:self.identifier] stringByAppendingPathComponent:self.attachmentName];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:path isDirectory:nil]) {
                if (! [fileManager removeItemAtPath:path error:&error]) {
                    AIQLogCError(1, @"Could not remove file of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                    [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
                    return;
                }
            }
            
            if (! [fileManager moveItemAtPath:[path stringByAppendingPathExtension:@"tmp"] toPath:path error:&error]) {
                AIQLogCError(1, @"Could not move file of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
                return;
            }
            
            if (! [db executeUpdate:@"UPDATE attachments SET state = ? WHERE solution = ? AND identifier = ? AND name = ?",
                   @(AIQAttachmentStateAvailable), self.solution, self.identifier, self.attachmentName]) {
                error = [db lastError];
                AIQLogCError(1, @"Could not update status of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
                return;
            }
            
            AIQLogCInfo(1, @"Attachment %@ ready for document %@", self.attachmentName, self.identifier);
            [[self synchronizer] attachmentDidBecomeAvailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
        } else {
            // attachment failed
            if ((_statusCode >= 400) && (_statusCode < 500)) {
                // permament failure
                
                if (! [db executeUpdate:@"UPDATE attachments SET state = ? WHERE solution = ? AND identifier = ? AND name = ?",
                       @(AIQAttachmentStateFailed), self.solution, self.identifier, self.attachmentName]) {
                    error = [db lastError];
                    AIQLogCError(1, @"Could not update status of attachment %@ for document %@: %@", self.attachmentName, self.identifier, error.localizedDescription);
                    [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
                    return;
                }
                
                AIQLogCInfo(1, @"Attachment %@ for document %@ permanently failed (%ld)", self.attachmentName, self.identifier, (long)_statusCode);
                [[self synchronizer] attachmentDidFail:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
            } else {
                // temporary failure
                AIQLogCInfo(1, @"Attachment %@ for document %@ temporarily failed (%ld)", self.attachmentName, self.identifier, (long)_statusCode);
                [[self synchronizer] attachmentDidBecomeUnavailable:self.attachmentName identifier:self.identifier type:self.type solution:self.solution];
            }
        }
    }];
    
    [self clean];
}

#pragma mark - Private API

- (void)clean {
    if (_handle) {
        [_handle synchronizeFile];
        [_handle closeFile];
        _handle = nil;
    }
    
    [super clean];
}

@end
