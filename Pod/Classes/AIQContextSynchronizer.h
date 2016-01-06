#import <Foundation/Foundation.h>

#import "AIQSynchronizer.h"

@class AIQSession;

@interface AIQContextSynchronizer : NSObject<AIQSynchronizer>

- (instancetype)initForSession:(AIQSession *)session;

@end
