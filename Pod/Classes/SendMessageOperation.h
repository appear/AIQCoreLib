@class AIQMessagingSynchronizer;

@interface SendMessageOperation : NSOperation

@property (nonatomic, retain) NSString *solution;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, retain) AIQMessagingSynchronizer *synchronizer;
@property (nonatomic, retain) NSThread *thread;

@end
