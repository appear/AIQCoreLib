#ifndef AIQCoreLib_AIQScheduler_h
#define AIQCoreLib_AIQScheduler_h

#import <Foundation/Foundation.h>

/*!
 @header AIQScheduler.h
 @author Marcin Lukow
 @copyright 2013 Appear Networks Systems AB
 @updated 2013-08-12
 @brief AIQScheduler module can be used to perform cyclic operations at given points in time.
 @version 1.0.0
 */

/** Polling interval for scheduler process.

 This polling interval is a time distance between checking if scheduled jobs need to be executed.This is
 the default value which is used when the AIQScheduler module was initialized without specifying the custom polling
 interval.
 
 @since 1.0.0
 @see initWithPollingInterval:
 */
EXTERN_API(NSTimeInterval) const AIQSchedulerPollingInterval;

/** AIQScheduler module.

 This module provides means to schedule cyclic execution of tasks.
 
 @since 1.0.0
 */
@interface AIQScheduler : NSObject

/**---------------------------------------------------------------------------------------
 * @name Initialization
 * ---------------------------------------------------------------------------------------
 */

/** AIQScheduler module constructor.

 This constructor initializes the AIQScheduler module with provided polling interval specifying how often
 scheduler checks for new tasks to be fired.

 @param interval Time interval specifying how often scheduler checks for new tasks to be fired. Must be positive.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return Initialized AIQScheduler module or nil if initialization failed, in which case the error parameter will
 contain the reason of failure.
 @since 1.0.0
 */
- (id)initWithPollingInterval:(NSTimeInterval)interval error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Job management
 * ---------------------------------------------------------------------------------------
 */

/** Schedules a recurring call to selector on object.

 This method can be used to schedule a recurring call of given selector on a given object. Selector is fired
 after every passed interval and upon adding or starting a scheduler, if it was not running at the time of scheduling
 the task.
 
 @param selector selector to call on the given object. Must not be nil.
 @param object object on which to call the selector. Must not be nil and must respond to the given selector.
 @param interval time distance between subsequent calls. Must be positive.
 @return Task identifier which can be used to unschedule the task. Will be nil in case of any error.
 @since 1.0.0
 @see scheduleCalling:on:with:every:
 */
- (NSString *)scheduleCalling:(SEL)selector on:(id)object every:(NSTimeInterval)interval;

/** Schedules a recurring call to selector on object.

 This method can be used to schedule a recurring call of given selector on a given object. Selector is fired
 after every passed interval and upon adding or starting a scheduler, if it was not running at the time of scheduling
 the task.
 
 @param selector selector to call on the given object. Must not be nil.
 @param object object on which to call the selector. Must not be nil and must respond to the given selector.
 @param argument argument which is passed to the selector. May be nil.
 @param interval time distance between subsequent calls. Must be positive.
 @return Task identifier which can be used to unschedule the task. Will be nil in case of any error.
 @since 1.0.0
 @see scheduleCalling:on:every:
 */
- (NSString *)scheduleCalling:(SEL)selector on:(id)object with:(id)argument every:(NSTimeInterval)interval;

/** Schedules a recurring call to selector on object.

 This method can be used to schedule a recurring call of given selector on a given object. Selector is fired
 after every passed interval and upon adding or starting a scheduler, if it was not running at the time of scheduling
 the task.
 
 @param selector selector to call on the given object. Must not be nil.
 @param object object on which to call the selector. Must not be nil and must respond to the given selector.
 @param argument argument which is passed to the selector. May be nil.
 @param interval time distance between subsequent calls. Must be positive.
 @param immediate tells whether to fire the job immediately after adding it to the pool
 @return Task identifier which can be used to unschedule the task. Will be nil in case of any error.
 @since 1.0.0
 @see scheduleCalling:on:every:
 */
- (NSString *)scheduleCalling:(SEL)selector
                           on:(id)object
                         with:(id)argument
                        every:(NSTimeInterval)interval
                    immediate:(BOOL)immediate;

/** Schedules a one time task.

 This method can be used to schedule a one time task at given point in time.

 @param selector Selector to call on the given object at given time. Must not be nil and must be
 callable on given object.
 @param object Object on which to perform a selector at given time. Must not be nil and must respond to the given
 selector.
 @param date Date on which to perform the selector. Must not be nil and must point to the future.
 @return Task identifier which can be used to unschedule the task. Will be nil in case of any error.
 @since 1.0.0
 @see call:on:with:at:
 */
- (NSString *)call:(SEL)selector on:(id)object at:(NSDate *)date;

/** Schedules a one time task.

 This method can be used to schedule a one time task at given point in time.

 @param selector Selector to call on the given object at given time. Must not be nil and must be
 callable on given object.
 @param object Object on which to perform a selector at given time. Must not be nil and must respond to the given
 selector.
 @param argument argument which to pass to the selector. May be nil.
 @param date Date on which to perform the selector. Must not be nil and must point to the future.
 @return Task identifier which can be used to unschedule the task. Will be nil in case of any error.
 @since 1.0.0
 @see call:on:at:
 */
- (NSString *)call:(SEL)selector on:(id)object with:(id)argument at:(NSDate *)date;

/** Unschedules a task from the scheduler.

 This method can be used to remove the task of given identifier from the scheduler cycle.

 @param identifier Identifier of the task to remove. Must not be nil.
 @return YES if the task was found and removed, NO otherwise.
 @since 1.0.0
 */
- (BOOL)unschedule:(NSString *)identifier;

/** Forces calling given task.

 This method can be used to force trigger a task of given identifier.

 @param identifier Identifier of the task for trigger. Must not be nil.
 @return YES if the task identified by given identifier was found and forced, NO otherwise.
 @since 1.0.0
 */
- (BOOL)force:(NSString *)identifier;

/**---------------------------------------------------------------------------------------
 * @name Other methods
 * ---------------------------------------------------------------------------------------
 */

/** Starts the scheduler.

 This method can be used to start the scheduler.

 @since 1.0.0

 @warning If the scheduler is already running, calling this method will not cause it to reschedule the next cycle.
 */
- (void)start;

/** Stops the scheduler.

 This method can be used to stop the scheduler.

 @since 1.0.0
 */
- (void)stop;

/** Tells whether the scheduler is running.

 This method can be used to check if the scheduler is running.

 @return YES if the scheduler is running, NO otherwise.
 @since 1.0.0
 */
- (BOOL)isRunning;

@end

#endif /* AIQCoreLib_AIQScheduler_h */
