#import <Foundation/Foundation.h>

#import "AIQSynchronizer.h"

@class AIQSession;

@interface AIQMessagingSynchronizer : NSObject<AIQSynchronizer>

- (instancetype)initForSession:(AIQSession *)session;
- (void)scheduleNextNotification;
- (void)pushMessages;
- (void)handleUnauthorized;

@end
