/*
 The MIT License (MIT)

 Copyright (c) 2015 Appear Networks AB

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#ifndef AIQCoreLib_AIQSession_h
#define AIQCoreLib_AIQSession_h

#import <Foundation/Foundation.h>

@class AIQDataStore;
@class AIQSynchronization;

/**
 Notifies that a session has been opened. There can be only one session opened at a time.
 */
EXTERN_API(NSString *) const AIQDidOpenSessionNotification;

/**
 Notifies that a session has been closed. And all subsequent calls made using any other AIQ
 module will fail.
 */
EXTERN_API(NSString *) const AIQDidCloseSessionNotification;

/**
 Default session request timeout in seconds.
 */
EXTERN_API(NSTimeInterval) const AIQDefaultSessionRequestTimeout;

/**
 Session key that can be used to retrieve the information about a user logged in for the
 current session. Will not be nil.
 
 @see kAIQUserEmail
 @see kAIQUserFullName
 @see kAIQUserGroups
 @see kAIQUserName
 @see kAIQUserPermissions
 @see kAIQUserProfile
 @see kAIQUserRoles
 */
EXTERN_API(NSString *) const kAIQUserInfo;

/**
 Key that can be used to retrieve the email address string from the user information stored within
 a session. May be nil.
 
 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserEmail;

/**
 Key that can be used to retrieve the full name string from the user information stored within a
 session. May be nil.
 
 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserFullName;

/**
 Key that can be used to retrieve an array of groups to which the current user belongs from
 the user information stored within a session. Will not be nil, may be empty.

 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserGroups;

/**
 Key that can be used to retrieve the username string from the user information stored within a
 session. Will not be nil.

 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserName;

/**
 Key that can be used to retrieve an array of permissions granted to the current user from the
 user information stored within a session. Will not be nil, may be empty.

 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserPermissions;

/**
 Key that can be used to retrieve a dictionary with user profile from the user information stored
 within a session. Will not be nil, may be empty.

 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserProfile;

/**
 Key that can be used to retrieve an array of roles assigned to the current user from the user 
 information stored within a session. Will not be nil, may be empty.

 @see kAIQUserInfo
 */
EXTERN_API(NSString *) const kAIQUserRoles;

/**
 A class that allows to log in to the Appear Mobility Platform and retrieve all the necessary
 information about the logged in user. It uses a custom implementation of the OAuth2 protocol to
 authenticate and authorize within the Cloud.
 */
@interface AIQSession : NSObject

/**
 An object representing the currently logged in user. Will be nil in case no session is opened.
 
 @return Currently opened session instance or nil when no session is opened.
 */
+ (instancetype)currentSession;

/**
 Tells whether it is possible to resume the last opened session.
 
 @return YES when it is possible to resume the last opened session or NO in case there is no saved
 session information or a session is already open.
 */
+ (BOOL)canResume;

/**
 Resumes the last opened session.
 
 @param error Will store the cause of an error in case when resuming fails. May be nil.
 @return Resumed session instance or nil when resuming has failed, in which case the error argument
 will store the cause of the error.
 */
+ (instancetype)resume:(NSError **)error;

/**
 Creates a new session.
 
 @param url URL to the mobility platform. Must not be nil.
 @return New session instance or nil in case the specified URL is invalid.
 
 @note Session created using the method is closed by default. You have to authenticate in order
 to be able to interact with the API.
 */
+ (instancetype)sessionWithBaseURL:(NSURL *)url;

/**
 Returns the timeout value for the authentication requests.
 
 @return Timeout interval in seconds.
 */
- (NSTimeInterval)timeout;

/**
 Sets the new timeout value for the authentication requests.
 
 @param timeout New timeout value. Value 0 disables the timeout.
 */
- (void)setTimeout:(NSTimeInterval)timeout;

/**
 Logs into the Appear Mobility Platform.
 
 @param username Name of the user to authenticate. Must not be nil and must be registered in your
 organization.
 @param password Password of the user to authenticate. Must not be nil. Will be validated by the
 Mobility Platform.
 @param organization Organization registered in the Mobility Platform. Must not be nil and must
 exist in the Mobility Platform.
 @param success Callback executed when the session has successfully opened. May be nil.
 @param failure Callback executed when the session has failed to open. Will receive an instance of
 NSError storing the cause of the error as a sole argument. May be nil.
 
 @see AIQDidOpenSessionNotification
 
 @note This call will fail if the session is already open.
 */
- (void)openForUser:(NSString *)username
           password:(NSString *)password
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;

/**
 Logs into the Appear Mobility Platform.

 @param username Name of the user to authenticate. Must not be nil and must be registered in your
 organization.
 @param password Password of the user to authenticate. Must not be nil. Will be validated by the
 Mobility Platform.
 @param info Custom parameters to be sent together with the authentication request to the Mobility
 Platform. May be nil or empty.
 @param organization Organization registered in the Mobility Platform. Must not be nil and must
 exist in the Mobility Platform.
 @param success Callback executed when the session has successfully opened. May be nil.
 @param failure Callback executed when the session has failed to open. Will receive an instance of
 NSError storing the cause of the error as a sole argument. May be nil.

 @see AIQDidOpenSessionNotification

 @note This call will fail if the session is already open.
 */
- (void)openForUser:(NSString *)username
           password:(NSString *)password
               info:(NSDictionary *)info
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;

/**
 Closes the session.
 
 @param success Callback executed when the sessin has successfully closed. May be nil.
 @param failure Callback executed when the session has failed to open. Will receive an instance of
 NSError storing the cause of the error as a sole argument. May be nil.
 
 @see AIQDidCloseSessionNotification

 @note This call will fail if the session is not open.
 */
- (void)close:(void (^)(void))success failure:(void (^)(NSError *error))failure;

/**
 Cancells the ongoing authentication request. Does nothing if the session is not authenticating.
 */
- (void)cancel;

/**
 Tells whether the session is open.
 
 @return YES if the session is open, NO otherwise.
 */
- (BOOL)isOpen;

/**
 Returns a session property identified by given key.
 
 @param key Session key to return a value for. Must not be nil.
 @return Property value or nil if not found or the session is not open.
 */
- (id)objectForKeyedSubscript:(NSString *)key;

/**
 Sets new value for a session property identified by given key.
 
 @param obj New value of the property to set. If nil, the property will be removed from the session.
 @param key Session key to return a value for. Must not be nil.
 
 @note The call will fail if the session is not open.
 */
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

/**
 Returns a data store which allows accesing business data belonging to a given solution.
 
 @param solution Solution identifier to create a data store for. Must not be nil.
 @return AIQDataStore instance or nil if given solution identifier was invalid or the session is
 not open.
 */
- (AIQDataStore *)dataStoreForSolution:(NSString *)solution;

/**
 Returns a business data synchronizer for the current session.
 
 @return AIQSynchronization instance or nil if the session is not open.
 */
- (AIQSynchronization *)synchronization;

@end

#endif /* AIQCoreLib_AIQSession_h */