#import "AIQError.h"
#import "AIQLog.h"
#import "AIQScheduler.h"

NSTimeInterval const AIQSchedulerPollingInterval = 10.0f;

@interface Job : NSObject

@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, retain) id object;
@property (nonatomic, retain) id argument;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, retain) NSDate *lastFired;
@property (nonatomic, assign) BOOL recurring;

@end

@implementation Job

- (NSString *)description {
    return self.identifier;
}

@end

@interface AIQScheduler ()

@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, retain) NSMutableArray *jobs; // Yo Steve!
@property (nonatomic, retain) dispatch_queue_t queue;

- (void)timerFired;

@end

@implementation AIQScheduler

- (id)init {
    return [self initWithPollingInterval:AIQSchedulerPollingInterval error:nil];
}

- (id)initWithPollingInterval:(NSTimeInterval)interval error:(NSError *__autoreleasing *)error {
    if ((error) && (*error)) {
        *error = nil;
    }
    
    BOOL success = YES;
    self = [super init];
    if (self) {
        if (interval > 0) {
            _jobs = [NSMutableArray array];
            _interval = interval;
            _identifier = [[NSUUID UUID] UUIDString];
            _queue = dispatch_queue_create([_identifier cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
            AIQLogCInfo(1, @"Initialized scheduler %@", _identifier);
        } else {
            success = NO;
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:@"Invalid polling interval"];
            }
        }
    }
    return success ? self : nil;
}

- (void)dealloc {
    dispatch_sync(_queue, ^{
        if (_timer) {
            [_timer invalidate];
            _timer = nil;
        }
    });
}

- (void)start {
    dispatch_sync(_queue, ^{
        if (! _timer) {
            AIQLogCInfo(1, @"Starting scheduler %@", _identifier);
            _timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                              interval:_interval
                                                target:self
                                              selector:@selector(timerFired)
                                              userInfo:nil
                                               repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:_timer
                                         forMode:NSDefaultRunLoopMode];
        } else {
            AIQLogCWarn(1, @"Scheduler %@ already running", _identifier);
        }
    });
}

- (void)stop {
    dispatch_sync(_queue, ^{
        if (_timer) {
            AIQLogCInfo(1, @"Stopping scheduler %@", _identifier);
            [_timer invalidate];
            _timer = nil;
            [_jobs removeAllObjects];
        } else {
            AIQLogCWarn(1, @"Scheduler not running %@", _identifier);
        }
    });
}

- (BOOL)isRunning {
    __block BOOL running = YES;
    dispatch_sync(_queue, ^{
        running = (_timer != nil);
    });
    return running;
}

- (NSString *)scheduleCalling:(SEL)selector
                           on:(id)object
                        every:(NSTimeInterval)interval {
    return [self scheduleCalling:selector
                              on:object
                            with:nil
                           every:interval
                       immediate:YES];
}

- (NSString *)scheduleCalling:(SEL)selector
                           on:(id)object
                         with:(id)argument
                        every:(NSTimeInterval)interval {
    return [self scheduleCalling:selector
                              on:object
                            with:argument
                           every:interval
                       immediate:YES];
}

- (NSString *)scheduleCalling:(SEL)selector
                           on:(id)object
                         with:(id)argument
                        every:(NSTimeInterval)interval
                    immediate:(BOOL)immediate {
    __block NSString *identifier = nil;

    if ([object respondsToSelector:selector]) {
        dispatch_sync(_queue, ^{
            Job *job = [[Job alloc] init];
            job.identifier = [[NSUUID UUID] UUIDString];
            job.object = object;
            job.argument = argument;
            job.selector = selector;
            job.interval = interval;
            job.lastFired = immediate ? nil : [NSDate date];
            job.recurring = YES;

            if (immediate) {
                AIQLogCInfo(1, @" Scheduling %@ every %lld seconds with immediate effect", job.identifier, (long long)round(interval));
            } else {
                AIQLogCInfo(1, @"Scheduling %@ every %lld seconds", job.identifier, (long long)round(interval));
            }
            [_jobs addObject:job];
            identifier = job.identifier;
        });
    } else {
        AIQLogCWarn(1, @"Object %@ does not respond to the selector %@", NSStringFromClass([object class]), NSStringFromSelector(selector));
    }
    
    return identifier;
}

- (NSString *)call:(SEL)selector on:(id)object at:(NSDate *)date {
    return [self call:selector on:object with:nil at:date];
}

- (NSString *)call:(SEL)selector
                on:(id)object
              with:(id)argument
                at:(NSDate *)date {
    __block NSString *identifier = nil;

    if ([object respondsToSelector:selector]) {
        dispatch_sync(_queue, ^{
            NSDate *now = [NSDate date];
            Job *job = [[Job alloc] init];
            job.identifier = [[NSUUID UUID] UUIDString];
            job.object = object;
            job.argument = argument;
            job.selector = selector;
            job.interval = [date timeIntervalSinceDate:now];
            job.lastFired = now;
            job.recurring = NO;

            AIQLogCInfo(1, @"Scheduling %@ on %@", job.identifier, date);
            [_jobs addObject:job];
            identifier = job.identifier;
        });
    } else {
        AIQLogCWarn(1, @"Object does not respond to the identifier");
    }
    
    return identifier;
}

- (BOOL)unschedule:(NSString *)identifier {
    __block BOOL found = NO;
    dispatch_sync(_queue, ^{
        for (int i = 0; (i < _jobs.count) && (! found); i++) {
            Job *job = _jobs[i];
            if ([job.identifier isEqualToString:identifier]) {
                AIQLogCInfo(1, @"Job %@ found, unscheduling", identifier);
                [_jobs removeObjectAtIndex:i];
                found = YES;
            }
        }
    });
    if (! found) {
        AIQLogCWarn(1, @"Job %@ not found", identifier);
    }
    return found;
}

- (BOOL)force:(NSString *)identifier {
    __block BOOL found = NO;
    dispatch_sync(_queue, ^{
        for (int i = 0; (i < _jobs.count) && (! found); i++) {
            Job *job = _jobs[i];
            if ([job.identifier isEqualToString:identifier]) {
                found = YES;
                if (job.lastFired) {
                    AIQLogCInfo(1, @"Job %@ found, forcing", identifier);
                    job.lastFired = [job.lastFired dateByAddingTimeInterval:-job.interval];
                }
                _timer.fireDate = [NSDate date];
            }
        }
    });
    if (! found) {
        AIQLogCWarn(1, @"Job %@ not found", identifier);
    }
    return found;
}

#pragma mark - Private API

- (void)timerFired {
    NSDate *now = [NSDate date];
    dispatch_sync(_queue, ^{
        for (int i = 0; i < _jobs.count; i++) {
            Job *job = _jobs[i];
            if (((! job.lastFired) && (job.recurring)) ||
                ([now timeIntervalSinceDate:job.lastFired] >= job.interval)) {
                if (! job.recurring) {
                    AIQLogCInfo(1, @"Removing non-recurring job %@", job.identifier);
                    [_jobs removeObjectAtIndex:i--];
                }
                AIQLogCInfo(1, @"Firing job %@", job.identifier);
                job.lastFired = now;
                [job.object performSelectorOnMainThread:job.selector withObject:job.argument waitUntilDone:NO];
            }
        }
    });
}

@end
