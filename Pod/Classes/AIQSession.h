#ifndef AIQCoreLib_AIQSession_h
#define AIQCoreLib_AIQSession_h

#import <Foundation/Foundation.h>

#define AIQ_DEPRECATED __attribute__((deprecated))

/*!
 @header AIQAuthentication.h
 @author Marcin Lukow
 @copyright 2012 Appear Networks Systems AB
 @updated 2014-03-20
 @brief AIQAuthentication module which can be used to authenticate user credentials against the Appear backend.
 @version 1.0.4
 */

/** Error code for invalid username/password.
 
 This error code is used for NSErrors raised when given credentials are invalid.
 
 @since 1.0.4
 @see session:openDidFailWithError:
 */
EXTERN_API(NSInteger) const AIQSessionCredentialsError;

/** Error code for unavailable backend.
 
 This error code is used for NSErrors raised when the backend is unavailable.
 
 @since 1.0.4
 @see session:openDidFailWithError:
 */
EXTERN_API(NSInteger) const AIQSessionBackendUnavailableError;

/** Timeout interval for authentication process.
 
 This timeout interval is used for making authentication requests to the backend under weak connectivity
 circumstances. This is the default value which is used when the AIQSession module was initialized without
 specifying the custom timeout interval.
 
 @since 1.0.4
 */
EXTERN_API(NSTimeInterval) const AIQSessionDefaultTimeoutInterval;

EXTERN_API(NSString *) const kAIQOrganizationName;

/** User info key for user profile information.
 
 This key is used to store the dictionary containing the full user profile information returned by the backend after
 the successful authentication. It can be used to retrieve the user profile form the User Info map passed to the
 delegate.
 
 @since 1.0.4
 @see propertyForName:
 */
EXTERN_API(NSString *) const kAIQUser;

/** User info key for connection status code.
 
 This key is used to store status code that is returned by the backend after failed authentication. It can
 be used to retrieve the status code from the User Info map passed to the delegate through the NSError instance.
 
 @since 1.0.4
 @see session:openDidFailWithError:
 */
EXTERN_API(NSString *) const kAIQStatusCode;

/** User info key for user identifier.
 
 This key can be used to retrieve the user identifier from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserId;

/** User info key for user name.
 
 This key can be used to retrieve the user name from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserName;

/** User info key for full user name.
 
 This key can be used to retrieve the full user name from the user profile dictionary.
 
 @warning This value is optional and may not be present in the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserFullName;

/** User info key for user profile details.
 
 This key can be used to retrieve the dictionary containing additional user details from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserProfile;

/** User info key for user email.
 
 This key can be used to retrieve the user email from the user profile dictionary.
 
 @warning This value is optional and may not be present in the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserEmail;

/** User info key for user roles.
 
 This key can be used to retrieve the array of user roles from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserRoles;

/** User info key for user groups.
 
 This key can be used to retrieve the array of user groups from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserGroups;

/** User info key for user permissions.
 
 This key can be used to retrieve the array of user permissions from the user profile dictionary.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const kAIQUserPermissions;

EXTERN_API(NSString *) const AIQSessionStatusCodeKey;

@class AIQContext;
@class AIQDataStore;
@class AIQDirectCall;
@class AIQLaunchableStore;
@class AIQLocalStorage;
@class AIQMessaging;
@class AIQSession;
@class AIQSynchronization;

/** Delegate for the AIQSession module.
 
 This delegate can be used to receive notifications about the outcome of the authentication process.
 
 @since 1.0.4
 */
@protocol AIQSessionDelegate <NSObject>

/** Notifies that the session has been opened.
 
 This method is called when the session has been successfully opened and is ready to use.
 
 @param session Session which has been opened. Will not be nil.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 */
- (void)sessionDidOpen:(AIQSession *)session;

/** Notifies that the session has failed to open.
 
 This method is called when the session has failed to open and cannot be used without prior reopening.
 
 @param session Session which has failed to open. Will not be nil.
 @param error Will store the cause of failure. Will not be nil.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 */
- (void)session:(AIQSession *)session openDidFailWithError:(NSError *)error;

/** Notifies that the session has been successfully closed.
 
 This method is called when the session has been closed and is no longer usable without prior reopening.
 Note that this method is called independependently of the logout request being send to the mobility
 platform.
 
 @param session Session which has been closed. Will not be nil.
 
 @since 1.0.4
 @see close:
 */
- (void)sessionDidClose:(AIQSession *)session;

/** Notifies that the session has failed to close.
 
 This method is called when the session has failed to close.
 
 @param session Session which has failed to close and is still usable. Will not be nil.
 @param error Will store the cause of failure. Will not be nil.
 
 @since 1.0.4
 @see close:
 */
- (void)session:(AIQSession *)session closeDidFailWithError:(NSError *)error;

@end

@interface AIQSession : NSObject

@property (nonatomic, retain) id<AIQSessionDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/** Returns currently open session.
 
 This method can be used to retrieve a session which is currently opened. If no session is open,
 this method will return nil.
 
 @return AIQSession instance if it is opened, nil otherwise.
 
 @since 1.0.4
 */
+ (AIQSession *)currentSession;

/** Tells whether it is possible to resume a suspended session.
 
 This method can be used to check whether it is possible to resume a session that hasn't been closed
 but is not open (in case of closing the application without logging out).
 
 @return YES if a session can be resumed, NO otherwise.
 
 @since 1.0.4
 @see resume:
 */
+ (BOOL)canResume;

/** Resumes a suspended session.
 
 This method can be used to resume a suspended session.
 
 @param error If defined, will store an error in case of any failure. May be nil.
 @return Resumed AIQSession module or nil if it has been impossible to resume a session, in which
 case the error parameter will contain the reason of failure.
 
 @since 1.0.4
 @see canResume
 */
+ (AIQSession *)resume:(NSError **)error;

/** Opens a new session.
 
 This method can be used to open a new session for given user. Note that it is impossible to open an
 already opened session, doing so will result in error.
 
 @param username The name of the user for which to open a session. Must not be nil and must be recognized
 by the mobility platform as belonging to given organization.
 @param password Password of the user for which to open a session. Must not be nil.
 @param organization The name of the organization to which the user belongs. Must not be nil and must be
 recognized by the mobility platform.
 @param baseURL Base URL of the mobility platform. Must not be nil.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return Opened AIQSession module or nil if initialization failed, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 @see close:
 @see isOpen
 */
- (BOOL)openForUser:(NSString *)username
       withPassword:(NSString *)password
     inOrganization:(NSString *)organization
            baseURL:(NSURL *)baseURL
              error:(NSError **)error;

/** Opens a new session.
 
 This method can be used to open a new session for given user. Note that it is impossible to open an
 already opened session. Doing so will result in error.
 
 @param username The name of the user for which to open a session. Must not be nil and must be recognized
 by the mobility platform as belonging to given organization.
 @param password Password of the user for which to open a session. Must not be nil.
 @param userInfo Additional information to be passed to the integration adapter. All properties stored
 in this map will be prefixed with x- prefix. May be nil.
 @param organization The name of the organization to which the user belongs. Must not be nil and must be
 recognized by the mobility platform.
 @param baseURL Base URL of the mobility platform. Must not be nil.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return Opened AIQSession module or nil if initialization failed, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 @see close:
 @see isOpen
 */
- (BOOL)openForUser:(NSString *)username
       withPassword:(NSString *)password
        andUserInfo:(NSDictionary *)userInfo
     inOrganization:(NSString *)organization
            baseURL:(NSURL *)baseURL
              error:(NSError **)error;

/** Closes the session.
 
 This method can be used to close the session and log out from the mobility platform. Note that it is not
 possible to close a session which has not been opened, doing so will result in error.
 
 @param error If defined, will store an error in case of any failure. May be nil.
 @return YES if the session has been successfully closed, NO otherwise, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 @see isOpen
 */
- (BOOL)close:(NSError **)error;

/** Tells whether the session is opening.
 
 This method can be used to check whether the session is opening.
 
 @return YES if the session is opening, NO otherwise.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 @see isOpen
 */
- (BOOL)isOpening;

/** Tells whether the session is open.
 
 This method can be used to check whether the session is open.
 
 @return YES if the session is open, NO otherwise.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 @see close:
 */
- (BOOL)isOpen;

/** Cancells the process of opening a session. Note that it is impossible to cancel a closed or already opened
 session, doing so will result in error.
 
 @param error If defined, will store an error in case of any failure. May be nil.
 @return YES if the process has been successfully cancelled, NO otherwise, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 @see openForUser:withPassword:inOrganization:baseURL:error:
 @see openForUser:withPassword:andUserInfo:inOrganization:baseURL:error:
 */
- (BOOL)cancel:(NSError **)error;

/** Returns the session identifier.
 
 This method can be used to return the session identifier. Note that only open sessions have identifiers assigned.
 
 @return Session identifier or nil if the session is not opened.
 
 @since 1.0.4
 */
- (NSString *)sessionId;

/** Returns a session property for given name.
 
 This method can be used to retrieve session properties. Note that it is impossible to retireve properties of a session
 which is closed or not yet opened.
 
 @param name The name of the property to retrieve. Must not be nil.
 @return Value of a property for given name. May be nil if given name does not exist within the session of if the session
 is not open.
 
 @since 1.0.4
 */
- (id)propertyForName:(NSString *)name;

- (void)setProperty:(id)property forName:(NSString *)name;

- (BOOL)hasRole:(NSString *)role;

- (BOOL)hasPermission:(NSString *)permission;

- (BOOL)solutions:(void (^)(NSString *solution, NSError **error))processor error:(NSError **)error;

/** Returns an instance of AIQContext module.
 
 This method can be used to retrieve an instance of AIQContext module connected to the session.
 
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQContext instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQContext *)context:(NSError **)error;

/** Returns an instance of AIQDataStore module.
 
 This method can be used to retrieve an instance of AIQDataStore module connected to the session.
 
 @param solution Identifier of a solution for which to return the data store. May be nil, in which case it defaults
 to a default solution identifier. If specified, must identify a valid solution.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQDataStore instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQDataStore *)dataStoreForSolution:(NSString *)solution error:(NSError **)error;

/** Returns an instance of AIQDirectCall module for given endpoint.
 
 This method can be used to retrieve an instance of AIQDirectCall module connected to the session.
 
 @param solution Identifier of a solution for which to return the data store. May be nil, in which case it defaults
 to a default solution identifier. If specified, must identify a valid solution.
 @param endpoint The name of the endpoint for which to create an instance of AIQDirectCall module. Must not be nil
 and must be recognized by the mobility platform.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQDirectCall instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQDirectCall *)directCallForSolution:(NSString *)solution endpoint:(NSString *)endpoint error:(NSError **)error;

- (AIQLaunchableStore *)launchableStore:(NSError **)error;

/** Returns an instance of AIQLocalStorage module.
 
 This method can be used to retrieve an instance of AIQLocalStorage module connected to the session.
 
 @param solution Identifier of a solution for which to return the data store. May be nil, in which case it defaults
 to a default solution identifier. If specified, must identify a valid solution.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQLocalStorage instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQLocalStorage *)localStorageForSolution:(NSString *)solution error:(NSError **)error;

/** Returns an instance of AIQMessaging module.
 
 This method can be used to retrieve an instance of AIQMessaging module connected to the session.
 
 @param solution Identifier of a solution for which to return the data store. May be nil, in which case it defaults
 to a default solution identifier. If specified, must identify a valid solution.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQMessaging instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQMessaging *)messagingForSolution:(NSString *)solution error:(NSError **)error;

/** Returns an instance of AIQSynchronization module.
 
 This method can be used to retrieve an instance of AIQSynchronization module connected to the session.
 
 @param error If defined, will store an error in case of any failure. May be nil.
 @return AIQSynchronization instance or nil if the module could not be initialized, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.4
 */
- (AIQSynchronization *)synchronization:(NSError **)error;

@end

#endif /* AIQCoreLib_AIQSession_h */
