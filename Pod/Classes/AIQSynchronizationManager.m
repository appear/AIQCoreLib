#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#endif

#import "AIQError.h"
#import "AIQLog.h"
#import "AIQSession.h"
#import "AIQSynchronizationManager.h"
#import "common.h"

#define BACKOFF_RATIO 2.0f

NSString *const AIQWillSynchronizeEvent = @"AIQWillSynchronizeEvent";
NSString *const AIQSynchronizationCompleteEvent = @"AIQSynchronizationCompleteEvent";

NSTimeInterval const AIQSynchronizationInterval = 60.0f;
NSUInteger const AIQSynchronizationQueueSize = 1;

@interface AIQSynchronizationManager () <AIQSynchronizationDelegate>

@property (nonatomic, retain) AIQSynchronization *synchronization;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, assign) NSUInteger synchronizationQueue;
@property (nonatomic, assign) NSTimeInterval lastSynchronizationTimestamp;
@property (nonatomic, assign) NSTimeInterval currentSynchronizationInterval;
@property (nonatomic, assign) BOOL isRunning;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, assign) BOOL isPaused;
#endif

@end

@implementation AIQSynchronizationManager

- (id)initForSynchronization:(AIQSynchronization *)synchronization error:(NSError *__autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    if (! synchronization) {
        if (error) {
            *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Synchronization not specified"];
        }
        return nil;
    }
    
    self = [super init];
    if (self) {
        synchronization.delegate = self;

        _synchronization = synchronization;


        // See if there's a specific synchronization interval in the session
        NSNumber *syncInterval = [[AIQSession currentSession] propertyForName:@"syncInterval"];

        if (syncInterval && syncInterval.intValue > 0) {
            _synchronizationInterval = syncInterval.intValue;
        } else {
            _synchronizationInterval = AIQSynchronizationInterval;
        }

        _queueSize = AIQSynchronizationQueueSize;

#if TARGET_OS_IPHONE
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
#endif
    }
    return self;
}

- (void)setSynchronizationInterval:(NSTimeInterval)synchronizationInterval {
    if (_currentSynchronizationInterval == _synchronizationInterval) {
        _currentSynchronizationInterval = synchronizationInterval;
    }
    _synchronizationInterval = synchronizationInterval;
}

- (BOOL)start:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        if (_isRunning) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Already running"];
            }
            return NO;
        }

        _isRunning = YES;
        _synchronizationQueue = 0;
        _lastSynchronizationTimestamp = [[NSDate date] timeIntervalSince1970];
        _currentSynchronizationInterval = AIQSynchronizationInterval;

#if TARGET_OS_IPHONE
        LISTEN(self, @selector(applicationDidEnterBackground:), UIApplicationDidEnterBackgroundNotification);
        LISTEN(self, @selector(applicationWillEnterForeground:), UIApplicationWillEnterForegroundNotification);
#endif

        [self scheduleNextSynchronizationTo:0];
        return YES;
    }
}

- (BOOL)stop:(NSError *__autoreleasing *)error {
        if (! _isRunning) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Not running"];
            }
            return NO;
        }

        [_timer invalidate];
        _timer = nil;

        if ([_synchronization isRunning]) {
            if (! [_synchronization cancel:error]) {
                return NO;
            }
        }

#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
        _isRunning = NO;

        return YES;
}

- (BOOL)force:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        if (! _isRunning) {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorContainerFault message:@"Not running"];
            }
            return NO;
        }

        [_timer invalidate];
        _timer = nil;

        _currentSynchronizationInterval = _synchronizationInterval;

        [self scheduleNextSynchronizationTo:0];

        return YES;
    }
}

- (void)forceWithCompletionHandler:(void (^)(AIQSynchronizationResult))handler {
    NOTIFY(AIQWillSynchronizeEvent, self, nil);
    _currentSynchronizationInterval = _synchronizationInterval;
    [_synchronization synchronizeWithCompletionHandler:handler];
    NOTIFY(AIQSynchronizationCompleteEvent, self, nil);

}

- (BOOL)isRunning {
    @synchronized(self) {
        return (_timer != nil);
    }
}

- (BOOL)isSynchronizing {
    @synchronized(self) {
        return [_synchronization isRunning];
    }
}

#pragma mark - AIQSynchronizationDelegate

- (void)didSynchronize:(AIQSynchronization *)synchronization {
    dispatch_async(dispatch_get_main_queue(), ^{
        _lastSynchronizationTimestamp = [[NSDate date] timeIntervalSince1970];
        _currentSynchronizationInterval = _synchronizationInterval;
        _synchronizationQueue--;
        AIQLogCInfo(1, @"Did synchronize");
        
        if (_synchronizationQueue == 0) {
            NOTIFY(AIQSynchronizationCompleteEvent, self, nil);
#if TARGET_OS_IPHONE
            if (_isPaused) {
                [self endBackgroundTask];
            } else {
#endif
                [self scheduleNextSynchronizationTo:_currentSynchronizationInterval];
#if TARGET_OS_IPHONE
            }
#endif
        } else {
#if TARGET_OS_IPHONE
            if (_isPaused) {
                [self endBackgroundTask];
            } else {
#endif
                AIQLogCInfo(1, @"Synchronization queue not empty, synchronizing again");
                NSError *error = nil;
                if (! [_synchronization synchronize:&error]) {
                    AIQLogCError(1, @"Could not synchronize: %@", error.localizedDescription);
                }
#if TARGET_OS_IPHONE
            }
#endif
        }
    });
}

- (void)synchronization:(AIQSynchronization *)synchronization didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        AIQLogCWarn(1, @"Synchronization failed: %@", error.localizedDescription);
        NOTIFY(AIQSynchronizationCompleteEvent, self, nil);
        _synchronizationQueue--;
        _synchronizationQueue = 0;
        _currentSynchronizationInterval /= BACKOFF_RATIO;

#if TARGET_OS_IPHONE
        if (_isPaused) {
            [self endBackgroundTask];
            return;
        }
#endif

        if (_currentSynchronizationInterval < BACKOFF_RATIO) {
            // Next backoff date will exceed the regular cycle date, let's fall back to the regular one for now
            AIQLogCInfo(1, @"Backoff interval exceeded, going back to %.2f seconds", _synchronizationInterval);
            _currentSynchronizationInterval = _synchronizationInterval;
        } else {
            AIQLogCInfo(1, @"Backoff fires in %.2f seconds", _currentSynchronizationInterval);
        }

        [self scheduleNextSynchronizationTo:_currentSynchronizationInterval];
    });
}

#pragma mark - Private API

- (void)synchronize {
    if (_synchronizationQueue == 0) {
        AIQLogCInfo(1, @"Synchronizing");
        _synchronizationQueue++;
        NSError *error = nil;
#if TARGET_OS_IPHONE
        [self beginBackgroundTask];
#endif
        NOTIFY(AIQWillSynchronizeEvent, self, nil);
        if (! [_synchronization synchronize:&error]) {
            AIQLogCError(1, @"Could not synchronize: %@", error.localizedDescription);
            _synchronizationQueue--;
#if TARGET_OS_IPHONE
            [self endBackgroundTask];
#endif
        }
    } else if (_synchronizationQueue < _queueSize) {
        AIQLogCInfo(1, @"Queueing synchronization");
        _synchronizationQueue++;
    } else {
        AIQLogCInfo(1, @"Synchronization queue full, ignoring");
    }
}

- (void)scheduleNextSynchronizationTo:(NSTimeInterval)interval {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:interval];
    AIQLogCInfo(1, @"Scheduling next synchronization to %@", date);
    _timer = [[NSTimer alloc] initWithFireDate:date interval:0.0f target:self selector:@selector(synchronize) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

#if TARGET_OS_IPHONE

- (void)beginBackgroundTask {
    if (_backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
        UIApplication *app = [UIApplication sharedApplication];
        _backgroundTaskIdentifier = [app beginBackgroundTaskWithExpirationHandler:^{
            if ([_synchronization isRunning]) {
                NSError *error = nil;
                if (! [_synchronization cancel:&error]) {
                    AIQLogCError(1, @"Failed to cancel ongoing synchronization: %@", error.localizedDescription);
                    abort();
                }
            }

            [self endBackgroundTask];
        }];
    }
}

- (void)endBackgroundTask {
    [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskIdentifier];
    _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (_isRunning) {
        AIQLogCInfo(1, @"Pausing");
        _isPaused = YES;
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    if (_isRunning) {
        AIQLogCInfo(1, @"Resuming");
        _isPaused = NO;
        [self scheduleNextSynchronizationTo:0.0f];
        /*
        NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSince1970] - _lastSynchronizationTimestamp;
        if (elapsedTime > _currentSynchronizationInterval) {
            AIQLogCInfo(1, @"Pause too long, forcing synchronization");
            [self scheduleNextSynchronizationTo:0.0f];
        } else {
            AIQLogCInfo(1, @"%.2f seconds left until synchronization", _currentSynchronizationInterval - elapsedTime);
            [self scheduleNextSynchronizationTo:_currentSynchronizationInterval - elapsedTime];
        }
         */
    }
}

#endif

@end
