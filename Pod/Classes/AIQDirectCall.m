#import "AIQDirectCall.h"
#import "AIQError.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "NSString+Helpers.h"

NSTimeInterval const AIQDirectCallTimeoutInterval = 60.0f;

NSString *const AIQDirectCallStatusCodeKey = @"AIQDirectCallStatusCode";

@interface AIQDirectCall () {
    AIQSession *_session;
    NSString *_solution;
    NSString *_endpoint;
    NSURLConnection *_connection;
    NSInteger _status;
    NSMutableData *_data;
    NSDictionary *_responseHeaders;
}

@end

@implementation AIQDirectCall

- (instancetype)initWithEndpoint:(NSString *)endpoint solution:(NSString *)solution forSession:(id)session error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }

    if (! endpoint) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Endpoint not specified"];
        }
        return nil;
    }
    
    if (! solution) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Solution not specified"];
        }
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
        _session = session;
        _solution = solution;
        _endpoint = endpoint;
        _method = @"GET";
        _timeoutInterval = AIQDirectCallTimeoutInterval;
    }
    return self;
}

- (void)start {
    if (_connection) {
        if (_delegate) {
            [_delegate directCall:self didFailWithError:[AIQError errorWithCode:AIQErrorContainerFault message:@"Already running"] headers:nil andData:nil];
        }
        return;
    }

    NSMutableArray *pairs = [NSMutableArray array];
    [pairs addObject:[NSString stringWithFormat:@"_endpoint=%@", _endpoint]];
    [pairs addObject:[NSString stringWithFormat:@"_solution=%@", _solution]];

    NSURL *url = [NSURL URLWithString:[_session propertyForName:@"direct"]];
    NSDictionary *query = [self queryAsDictionaryForURL:url];
    for (NSString *key in query) {
        id value = query[key];
        NSString *string = [[NSString stringWithFormat:@"%@", value] URLEncode];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, string]];
    }

    if (_parameters) {
        for (NSString *key in _parameters) {
            NSString *sanitizedKey = [key URLEncode];
            id value = _parameters[key];
            NSString *string = [[NSString stringWithFormat:@"%@", value] URLEncode];
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", sanitizedKey, string]];
        }
    }

    NSString *target = [NSString stringWithFormat:@"?%@", [pairs componentsJoinedByString:@"&"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:target relativeToURL:url]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_timeoutInterval];
    [request setValue:[NSString stringWithFormat:@"BEARER %@", [_session propertyForName:@"accessToken"]] forHTTPHeaderField:@"Authorization"];

    if (_headers) {
        NSString *accept = _headers[@"Accept"];
        if (accept) {
            if (([accept isEqualToString:@"application/json"]) || ([accept hasPrefix:@"text/"])) {
                AIQLogCInfo(1, @"Plain Accept header, forcing data compression");
                [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
            } else {
                // Deflation for binary data adds around 30 seconds to the response, thanks iOS!
                AIQLogCInfo(1, @"Binary Accept header, forcing uncompressed data transfer");
                [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
            }
        } else {
            AIQLogCInfo(1, @"No Accept header, forcing uncompressed data transfer");
            [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
        }
        for (NSString *header in _headers) {
            if (! [header isEqualToString:@"Authorization"]) {
                [request setValue:_headers[header] forHTTPHeaderField:header];
            }
        }
    } else {
        AIQLogCInfo(1, @"No headers, forcing uncompressed data transfer");
        [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
    }

    request.HTTPMethod = _method;

    if (([_method isEqualToString:@"GET"]) || ([_method isEqualToString:@"DELETE"])) {
        AIQLogCInfo(1, @"Calling %@ with %@", _endpoint, _method);
        request.HTTPBody = nil;
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_connection start];
    } else if (_body) {
        request.HTTPBody = _body;
        if (_contentType) {
            [request setValue:_contentType forHTTPHeaderField:@"Content-Type"];
        } else {
            AIQLogCInfo(1, @"No content type for %@, falling back to octet stream", _endpoint);
            [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
        }
        AIQLogCInfo(1, @"Calling %@ with %@", _endpoint, _method);
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_connection start];
    } else {
        [_delegate directCall:self didFailWithError:[AIQError errorWithCode:AIQErrorInvalidArgument message:@"Body not specified"] headers:nil andData:nil];
    }
}

- (BOOL)isRunning {
    return (_connection != nil);
}

- (void)cancel {
    if (_connection) {
        AIQLogCInfo(1, @"Cancelling");
        [_connection cancel];
        [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _connection = nil;
        if (_delegate) {
            [_delegate directCallDidCancel:self];
        }
    }
}

- (void)setMethod:(NSString *)method {
    if (method) {
        _method = [method uppercaseString];
        if ((! [_method isEqualToString:@"GET"]) &&
            (! [_method isEqualToString:@"POST"]) &&
            (! [_method isEqualToString:@"PUT"]) &&
            (! [_method isEqualToString:@"DELETE"])) {
            AIQLogCWarn(1, @"Unknown method: %@, falling back to GET", method);
            _method = @"GET";
        }
    } else {
        _method = @"GET";
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Did fail: %@", error);
    [connection cancel];
    [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _connection = nil;
    if (_delegate) {
        [_delegate directCall:self didFailWithError:[AIQError errorWithCode:AIQErrorConnectionFault userInfo:error.userInfo] headers:nil andData:nil];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    _status = httpResponse.statusCode;
    AIQLogCInfo(1, @"Did receive response %ld", (long)_status);

    if (httpResponse.expectedContentLength == -1) {
        _data = [NSMutableData data];
    } else {
        _data = [NSMutableData dataWithCapacity:(NSUInteger)httpResponse.expectedContentLength];
    }
    _responseHeaders = httpResponse.allHeaderFields;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [_connection unscheduleFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    NSData *data = [_data copy];
    _data = nil;

    NSDictionary *headers = (_responseHeaders == nil) ? @{} : [_responseHeaders copy];
    _responseHeaders = nil;

    NSInteger status = _status;
    _status = 0;

    if (_delegate) {
        if ((status >= 200) && (status < 300)) {
            [_delegate directCall:self didFinishWithStatus:status headers:headers andData:data];
        } else {
            AIQError *error = [AIQError errorWithCode:AIQErrorConnectionFault userInfo:@{NSLocalizedDescriptionKey: @"Invalid response from AIQ Server",
                                                                                    AIQDirectCallStatusCodeKey: @(status)}];
            [_delegate directCall:self didFailWithError:error headers:headers andData:data];
        }
    }
}

#pragma mark - Private API

- (NSDictionary *)queryAsDictionaryForURL:(NSURL *)url {
    NSArray *params = [url.query componentsSeparatedByString:@"&"];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:params.count];
    for (NSString *param in params) {
        NSArray *pair = [param componentsSeparatedByString:@"="];
        result[pair[0]] = pair[1];
    }
    return [result copy];
}

@end
