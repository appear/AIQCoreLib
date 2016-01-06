#import <Foundation/Foundation.h>

#import "AIQSynchronizer.h"

@class AIQSession;

@interface AIQLaunchableSynchronizer : NSObject<AIQSynchronizer>

- (instancetype)initForSession:(AIQSession *)session;

@end
