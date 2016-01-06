#import "AIQSynchronization.h"
#import "AIQSynchronizer.h"

@class FMDatabasePool;

@interface AIQOperation : NSOperation

@property (nonatomic, retain) AIQSynchronization *synchronization;
@property (nonatomic, retain) NSString *attachmentName;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, retain) NSString *solution;
@property (nonatomic, retain) NSString *type;
@property (nonatomic, assign) NSTimeInterval timeout;

- (void)connectUsingRequest:(NSURLRequest *)request;
- (void)clean;
- (FMDatabasePool *)pool;
- (NSString *)accessToken;
- (NSString *)basePath;
- (void)storeLinks:(NSDictionary *)links;
- (id)sessionPropertyWithName:(NSString *)name;
- (BOOL)processStatusCode:(NSInteger)statusCode;
- (AIQRejectionReason)reasonFromStatusCode:(NSInteger)statusCode;
- (id<AIQSynchronizer>)synchronizer;

- (void)onStart;

@end
