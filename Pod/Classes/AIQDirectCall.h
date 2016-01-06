#ifndef AIQCoreLib_AIQDirectCall_h
#define AIQCoreLib_AIQDirectCall_h

#import <Foundation/Foundation.h>

/*!
 @header AIQDirectCall.h
 @author Marcin Lukow
 @copyright 2013 Appear Networks Systems AB
 @updated 2013-08-12
 @brief AIQDirectCall module can be used to perform direct calls to the backend.
 @version 1.0.0
 */

@class AIQSession;
@class AIQDirectCall;

/** Timeout interval for direct call process.

 This timeout interval is used for making direct call requests to the backend under weak connectivity
 circumstances. This is the default value which is used when the AIQDirectCall module was initialized without
 specifying the custom timeout interval.
 
 @since 1.0.0
 @see initWithURL:endpoint:timeoutInterval:andAccessToken:
 */
EXTERN_API(NSTimeInterval) const AIQDirectCallTimeoutInterval;

/** Status code key.

 This key can be used to retrieve the status code from the user info dictionary of the NSError instance.
 
 @since 1.0.0
 @see directCall:didFailWithError:
 */
EXTERN_API(NSString *) const AIQDirectCallStatusCodeKey;

/** Delegate for the DirectCall module.

 This delegate can be used to receive notifications about the outcome of the direct call.
 
 @since 1.0.0
 */
@protocol AIQDirectCallDelegate <NSObject>

@required

/** Notifies about successful call.

 This method notifies that the direct call has succeeded and provides the JSON document returned
 by the backend.

 @param directCall AIQDirectCall module instance which the delegate belongs to. Will not be nil.
 @param status Response code returned by the backend.
 @param headers Response headers returned by the backend. Will not be nil, may be empty.
 @param data Data object returned by the backend. Will not be nil.
 @since 1.0.0
 */
- (void)directCall:(AIQDirectCall *)directCall
didFinishWithStatus:(NSInteger)status
           headers:(NSDictionary *)headers
           andData:(NSData *)data;

/** Notifies about failed call.

 This method notifies that the direct call has failed and provides a detailed description of
 the failure.

 @param directCall AIQDirectCall module instance which the delegate belongs to. Will not be nil.
 @param error Error describing the failure. Will not be nil.
 @param headers Response headers returned by the backend. Will not be nil.
 @param data Response body returned by the backend. May be nil.
 @since 1.0.0
 @see AIQDirectCallErrorDomain
 @see AIQDirectCallClientError
 @see AIQDirectCallConnectionError
 @see AIQDirectCallBackendError
 */
- (void)directCall:(AIQDirectCall *)directCall
  didFailWithError:(NSError *)error
           headers:(NSDictionary *)headers
           andData:(NSData *)data;

/** Notifies about cancelled call.

 This method notifies that the direct call has been cancelled.

 @param directCall AIQDirectCall module instance which the delegate belongs to. Will not be nil.
 @since 1.0.0
 */
- (void)directCallDidCancel:(AIQDirectCall *)directCall;

@end

/** AIQDirectCall module.

 This module provides means to perform direct calls to the backend.
 
 @since 1.0.0
 */
@interface AIQDirectCall : NSObject<NSURLConnectionDataDelegate>

/**---------------------------------------------------------------------------------------
 * @name Properties
 * ---------------------------------------------------------------------------------------
 */

/** AIQDirectCall delegate.

 This delegate, if specified, will be notified about the outcome of the direct call. May be nil.
 
 @since 1.0.0
 @see AIQDirectCallDelegate
 */
@property (nonatomic, retain) id<AIQDirectCallDelegate> delegate;

/** Request method to use.

 This property stores the HTTP method to be used to perform the direct call. Can be one of GET,
 POST, PUT or DELETE. If nil, it falls back to GET.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSString *method;

/** Request parameters.

 This property stores the URL parameters to be passed to the backend. May be nil.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSDictionary *parameters;

/** Request body.

 This property stores the request body to be sent to the backend. Must be nil for non-modifying
 methods (GET, DELETE), may be nil for other methods.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSData *body;

/** Content type of the request body.

 This property stores the content type of the body to be sent to the backend. Must be nil for
 non-modifying methods (GET, DELETE), may be nil for other methods. If nil when body property is not nil,
 it defaults to application/octet-stream.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSString *contentType;

/** Request headers.

 This property stores the HTTP headers to be sent to the backend. May be nil.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSDictionary *headers;

/** Request timeout.
 
 This property stores the request timeout interval, after which the call will fail. Default value is defined
 by AIQDirectCallTimeoutInterval.
 
 @since 1.0.0
 @see AIQDirectCallTimeoutInterval
 */
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/**---------------------------------------------------------------------------------------
 * @name Other methods
 * ---------------------------------------------------------------------------------------
 */

/** Performs the direct call.

 This method can be used to perform the direct call.

 @since 1.0.0
 @see directCall:didFinishWithStatus:headers:andData:
 @see directCall:didFailWithError:headers:andData:
 @see directCallDidCancel:
 
 @warning This method will fail if the direct call request is already in progress.
 */
- (void)start;

/** Tells whether the direct call is in progress.

 This method can be used to tell whether the direct call request is in progress.

 @return YES if the direct call request is in progress, NO otherwise.
 @since 1.0.0
 */
- (BOOL)isRunning;

/** Cancels the direct call.

 This method can be used to cancel the ongoing direct call.
 
 @since 1.0.0
 @see directCall:didFailWithError:headers:andData:
 @see directCallDidCancel:
 
 @warning This method will fail if the direct call request is not running.
 */
- (void)cancel;

@end

#endif /* AIQCoreLib_AIQDirectCall_h */
