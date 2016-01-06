#ifndef AIQCoreLib_AIQMessaging_h
#define AIQCoreLib_AIQMessaging_h

#import <Foundation/Foundation.h>

/*!
 @header AIQMessaging.h
 @author Marcin Lukow
 @copyright 2013 Appear Networks Systems AB
 @updated 2013-08-12
 @brief AIQMessaging module can be used to send and receive messages from and to the backend.
 @version 1.0.0
 */

/** Message sorting order.
 
 This enumeration contains all possible message orders in which to retrieve messages. Messages are ordered
 by activeFrom and created fields.
 
 @since 1.0.0
 */
typedef NS_ENUM(NSInteger, AIQMessageOrder) {
    
    /** Retrieve messages in ascending order.
     
     @since 1.0.0
     */
    AIQMessageOrderAscending  = 0,
    
    /** Retrieve messages in descending order.
     
     @since 1.0.0
     */
    AIQMessageOrderDescending = 1
};

/** Client originated message state.
 
 This enumeration contains all possible states in which client originated messages can be. Message is created
 with queued state. After it has been sent to the mobility platform, it can be either accepted or rejected by it.
 When it gets accepted, it is forwarded to the specified destination. Successful delivery makes the message transit
 to delivered state, otherwise the message is failed.
 
 @since 1.0.4
 */
typedef NS_ENUM(NSInteger, AIQMessageState) {
    
    /** Initial message state before being send to the mobility platform.
     
     @since 1.0.4
     */
    AIQMessageStateQueued = 0,
    
    /** Message has been accepted by the mobility platform and will be forwarded to the specified destination.
     
     @since 1.0.4
     */
    AIQMessageStateAccepted = 1,
    
    /** Message is invalid or has been rejected by the mobility platform and will not be forwarded to the specified
     destination.
     
     @since 1.0.4
     */
    AIQMessageStateRejected = 2,
    
    /** Message has been successfully delivered to the specified destination.
     
     @since 1.0.4
     */
    AIQMessageStateDelivered = 3,
    
    /** Message has been rejected by the specified destination or the specified does not exist.
     
     @since 1.0.4
     */
    AIQMessageStateFailed = 4
};

@class AIQSession;

/** User info key for message type.
 
 This key is used to store a type of a message stored within the AIQDataStore. It can be used to retrieve the
 type from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageType;

/** User info key for message destination.
 
 This key is used to store a destination of a client originated message. It can be used to retrieve the destination
 from a message status returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.4
 @see statusOfMessageWithId:error:
 @see statusesOfMessagesForDestination:error:
 @see statusesOfMessagesForDestination:filter:error:
 */
EXTERN_API(NSString *) const kAIQMessageDestination;

/** User info key for message state.
 
 This key is used to store a state of a client originated message. It can be used to retrieve the state from a message
 status retured by one of the AIQMessaging accessor methods.
 
 @since 1.0.4
 @see AIQMessageState
 @see statusOfMessageWithId:error:
 @see statusesOfMessagesForDestination:error:
 @see statusesOfMessagesForDestination:filter:error:
 */
EXTERN_API(NSString *) const kAIQMessageState;

EXTERN_API(NSString *) const kAIQMessageLaunchable;

/** User info key for message response body.
 
 This key is used to store a response body for a client originated message. It can be used to retrieve the response body
 from a message status returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.4
 @see statusOfMessageWithId:error:
 @see statusesOfMessagesForDestination:error:
 @see statusesOfMessagesForDestination:filter:error:
 */
EXTERN_API(NSString *) const kAIQMessageBody;

/** User info key for message creation timestamp.
 
 This key is used to store a creation timestamp of a message stored within the AIQDataStore. It can be used to
 retrieve the creation timestamp (in milliseconds) from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageCreated;

/** User info key for message activation timestamp.
 
 This key is used to store an activation timestamp of a message stored within the AIQDataStore. It can be used
 to retrieve the activation timestamp (in milliseconds) from a message returned by one of the AIQMessaging accessor
 methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageActiveFrom;

/** User info key for message time to live.
 
 This key is used to store a time to live of a message stored within the AIQDataStore. It can be used to
 retrieve the time to live (in seconds) from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageTimeToLive;

/** User info key for message read flag.
 
 This key is used to store the information whether the message was read. It can be used to retrieve the read
 flag from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageRead;

/** User info key for message urgency flag.
 
 This key is used to store the information whether the message is urgent. It can be used to retrieve the urgency
 flag from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageUrgent;

/** User info key for message relevance.
 
 This key is used to store the information whether the message is relevant to the current user. It can be
 used to retrieve the relevance flag from a message returned by one of the AIQMessaging accessor methods. Note that
 relevance is calculated using the AIQContext module, so if it has not been provided to the AIQMessaging module, all
 messages will be marked as relevant.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageRelevant;

/** User info key for message payload.
 
 This key is used to store a payload of a message stored within the AIQDataStore. It can be used to retrieve
 the payload from a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessagePayload;

/** User info key for message text.
 
 This key is used to store a payload of a message stored within the AIQDataStore. It can be used to retrieve
 the text of a message returned by one of the AIQMessaging accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageText;

/** User info key for message sound flag.
 
 This key is used to store a sound flag of a message stored within the AIQDataStore. It can be used to retrieve
 the information on whether to play a sound upon receiving of a message returned by one of the AIQMessaging accessor
 methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageSound;

/** User info key for message vibrate flag.
 
 This key is used to store a vibrate flag of a message stored within the AIQDataStore. It can be used to
 retrieve the information on whether to vibrate the device upon receiving of a message returned by one of the AIQMessaging
 accessor methods.
 
 @since 1.0.0
 @see messageForId:error:
 @see messagesOfType:error:
 */
EXTERN_API(NSString *) const kAIQMessageVibrate;

/** Message received event name.
 
 This is the name of the event generated by NSNotificationCenter when a message has been received and stored
 in the local data store.
 
 @since 1.0.0
 */
EXTERN_API(NSString *) const AIQDidReceiveMessageNotification;

/** Message updated event name.
 
 This is the name of the event generated by NSNotificationCenter when a message has been updated in the
 local data store.
 
 @since 1.0.0
 */
EXTERN_API(NSString *) const AIQDidUpdateMessageNotification;

/** Message expired event name.
 
 This is the name of the event generated by NSNotificationCenter when a message has expired and is about to
 be deleted from the local data store.
 
 @since 1.0.0
 */
EXTERN_API(NSString *) const AIQDidExpireMessageNotification;

/** Message read event name.
 
 This is the name of the event generated by NSNotificationCenter when a message has been marked as read.
 
 @since 1.0.0
 
 @warning When a message is updated, it changes is status to unread.
 */
EXTERN_API(NSString *) const AIQDidReadMessageNotification;

/** Message attachment available event name.
 
 This is the name of the event generated by NSNotificationCenter when a server originated message attachment
 has been successfully downloaded and is available in the client.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQMessageAttachmentDidBecomeAvailableNotification;

/** Message attachment unavailable event name.
 
 This is the name of the event generated by NSNotificationCenter when a server originated message attachment
 becomes unavailable due to it being downloaded from the mobility platform. All unavailable attachments are
 retried.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQMessageAttachmentDidBecomeUnavailableNotification;

/** Message attachment failed event name.
 
 This is the name of the event generated by NSNotificationCenter when a server originated message attachment
 has failed to download and will not be retried.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQMessageAttachmentDidFailEvent;

/** Message queued event name.
 
 This is the name of the event generated by NSNotificationCenter when a client originated message is created
 and will be send to the mobility platform.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQDidQueueMessageNotification;

/** Message accepted event name.
 
 This is the name of the event generated by NSNotificationCenter when a client originated message is accepted
 by the mobility platform and will be forwarded to the specified destination.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQDidAcceptMessageNotification;

/** Message rejected event name.
 
 This is the name of the event generated by NSNotificationCenter when a client originated message is invalid
 or rejected by the mobility platform and will not be forwarded to the specified destination.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQDidRejectMessageNotification;

/** Message delivered event name.
 
 This is the name of the event generated by NSNotificationCenter when a client originated message is delivered
 to the specified destination.
 
 @since 1.0.4
 */
EXTERN_API(NSString *) const AIQDidDeliverMessageNotification;

/** Message failed event.
 
 This is the name of the event generated by NSNotificationCenter when a client originated message is rejected by
 the specified destination or the specified destination does not exist.
 */
EXTERN_API(NSString *) const AIQDidFailMessageNotification;

EXTERN_API(NSString *) const AIQMessageTypeUserInfoKey;

EXTERN_API(NSString *) const AIQMessageDestinationUserInfoKey;

/** AIQMessaging module.
 
 Messaging module can be used to access active message documents.
 
 @since 1.0.0
 @see AIQDataStore
 */
@interface AIQMessaging : NSObject

/** Closes the messaging module.
 
 This method must be used at the end of the data store lifecycle to enforce the data consistency.
 
 @since 1.0.0
 */
- (void)close;

/**---------------------------------------------------------------------------------------
 * @name Message management
 * ---------------------------------------------------------------------------------------
 */

/** Tells whether a message with given identifier exists.
 
 This method can be used to check if a message with given identifier exists in the data store. This
 method is failsafe so it will return NO in case of any error.
 
 @param identifier Identifier of a message for which to check the existence. Must not be nil.
 @return YES if message with given identifier exists, NO otherwise or in case of any errors.
 
 @since 1.0.0
 */
- (BOOL)messageExistsWithId:(NSString *)identifier;

/** Returns message for given identifier.
 
 This method can be used to retrieve a message identifier by its identifier.
 
 @param identifier Identifier of a message to retrieve. Must not be nil and must exist in the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return AIQMessage for given identifier or nil if the message could not be found or if retrieving failed, in which case
 the error parameter will contain the reason of failure.
 
 @since 1.0.0
 */
- (NSDictionary *)messageForId:(NSString *)identifier error:(NSError **)error;

/** Returns messages of given type.
 
 This method can be used to retrieve a list of messages identified by given message type. The resulting list
 is sorted by relevance date, i.e. first by activeFrom field and then by created field in case messages have the same
 activeFrom field values. In case when both fields are equal, message order is undefined.
 
 @param type Type of messages to retrieve. Must not be nil.
 @param order Order in which to return messages.
 @param processor Processor to be applied to raw messages before adding to the result array. If the
 processor sets an error passed as its argument, the whole call will fail with given error. Must not be nil.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the processing finished successfully, NO otherwise, in which case the error parameter will contain the
 reason of failure.
 
 @since 1.0.0
 @see AIQMessageOrder
 */
- (BOOL)messagesOfType:(NSString *)type
                 order:(AIQMessageOrder)order
             processor:(void (^)(NSDictionary *, NSError **))processor
                 error:(NSError **)error;



/** Marks message as read.
 
 This method can be used to mark a message identified by given identifier as read.
 
 @param identifier Identifier of a message to mark as read. Must not be nil and must exist.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the message was successfully marked as read, NO otherwise, in which case the error parameter will
 contain the reason of failure.
 
 @since 1.0.0
 */
- (BOOL)markMessageAsReadForId:(NSString *)identifier error:(NSError **)error;

/** Deletes a message.
 
 This method can be used to delete the local copy of a message identified by given identifier.
 
 @param identifier Identifier of a message to delete. Must not be nil and must exist.
 @param error If defiled, will store an error in case of any failures. May be nil.
 @return YES if the message was successfully deleted, NO otherwise, in which case the error parameter will contain
 the reason of failure.
 
 @since 1.0.4
 
 @note Deleting a message does not remove it from the mobility platform.
 */
- (BOOL)deleteMessageWithId:(NSString *)identifier error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Attachment management
 * ---------------------------------------------------------------------------------------
 */

/** Tells whether an attachment with given name exists for a message with given identifier.
 
 This method can be used to check if an attachment with given name exists for a message with given
 identifier. This method is failsafe so it will return NO in case of any error.
 
 @param name Name of the attachment for which to check the existence. Must not be nil.
 @param identifier Identifier of a message for which to check the existence. Must not be nil.
 @return YES if attachment with given identifier exists, NO otherwise or in case of any errors.
 
 @since 1.0.2
 */
- (BOOL)attachmentWithName:(NSString *)name existsForMessageWithId:(NSString *)identifier;

/** Returns an attachment for given name and message identifier.
 
 This method can be used to retrieve an attachment with given name for a message with given identifier.
 
 @param name Name of an attachment to retrieve. Must not be nil and must exist in the data store.
 @param identifier Identifier of a message for which to retrieve the attachment. Must not be nil and must exist in
 the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Attachment for given name and message identifier or nil if the attachment could not be found or if retrieving
 failed, in which case the error parameter will contain the reason of failure.
 
 @since 1.0.2
 */
- (NSDictionary *)attachmentWithName:(NSString *)name forMessageWithId:(NSString *)identifier error:(NSError **)error;

/** Processes attachments for a message with given identifier.
 
 This method can be used to retrieve a list of attachments belonging to a message with given identifier.
 
 @param identifier Identifier of a message for which to retrieve the attachments. Must not be nil and must exist in
 the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return An array of attachment descriptors. May be nil if the attachments could not be retrieved, in which case the
 error parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSArray *)attachmentsForMessageWithId:(NSString *)identifier error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Data management
 * ---------------------------------------------------------------------------------------
 */

/** Retrieves the data for given resource identifier.
 
 This method can be used to retrieve the data for given resource identifier.
 
 @param name Name of the attachment for which to return the data. Must not be nil and must exist in the data store.
 @param identifier Message identifier for which to return the data. Must not be nil and must exist in the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Data for given attachment or nil if the data does not exist or if retrieving failed, in which case the error
 parameter will contain the reason of failure.
 @since 1.0.0
 */

- (NSData *)dataForAttachmentWithName:(NSString *)name fromMessageWithId:(NSString *)identifier error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Client originated messaging
 * ---------------------------------------------------------------------------------------
 */

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload to:(NSString *)destination error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param attachments An optional array of attachment descriptors to be sent together with the messages. May be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload withAttachments:(NSArray *)attachments to:(NSString *)destination error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param urgent Indicates whether the message should be dispatched immediately. If not, it will be placed in the queue
 and dispatched together with the next urgent message.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload to:(NSString *)destination urgent:(BOOL)urgent error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param expectResponse Indicates whether the message is expected to get a response from your enterprise IT server. If not,
 message status will be deleted immediately after being accepted by the mobility platform.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload to:(NSString *)destination expectResponse:(BOOL)expectResponse error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param attachments An optional array of attachment descriptors to be sent together with the messages. May be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param urgent Indicates whether the message should be dispatched immediately. If not, it will be placed in the queue
 and dispatched together with the next urgent message.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload withAttachments:(NSArray *)attachments to:(NSString *)destination urgent:(BOOL)urgent error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param attachments An optional array of attachment descriptors to be sent together with the messages. May be nil.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param expectResponse Indicates whether the message is expected to get a response from your enterprise IT server. If not,
 message status will be deleted immediately after being accepted by the mobility platform.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                           to:(NSString *)destination
               expectResponse:(BOOL)expectResponse
                        error:(NSError **)error;

/** Creates a client originated message.
 
 This method can be used to create a client originated message to be dispatched to the given destination.
 
 @param payload Message payload to be send to the given destination. Must not be nil.
 @param attachments An optional array of attachment descriptors to be sent together with the messages. May be nil.
 @param identifier Identifier of a launchable to be indicated as a message sender. Can be nil. If not nil, must reference
 a launchable.
 @param destination The name of the destination to which to dispatch the message. Must not be nil and must be registered
 in the mobility platform.
 @param urgent Indicates whether the message should be dispatched immediately. If not, it will be placed in the queue
 and dispatched together with the next urgent message.
 @param expectResponse Indicates whether the message is expected to get a response from your enterprise IT server. If not,
 message status will be deleted immediately after being accepted by the mobility platform.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the queued message or nil if the message could not be queued, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.5
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)sendMessage:(NSDictionary *)payload
              withAttachments:(NSArray *)attachments
                         from:(NSString *)identifier
                           to:(NSString *)destination
                       urgent:(BOOL)urgent
               expectResponse:(BOOL)expectResponse
                        error:(NSError **)error;

/** Returns a status of a client originated message.
 
 This method can be used to retrieve a status descriptor of a client originated message.
 
 @param identifier Identifier of a client originated message for which to retreive a status. Must not be nil and
 must reference a client originated message.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Status descriptor of the message or nil if the message status could not be retrieved, in which case the error
 parameter will contain the reason of failure.
 
 @since 1.0.4
 @see AIQMessagingErrorDomain
 @see AIQMessagingClientError
 @see AIQMessageDestinationKey
 @see AIQMessageStateKey
 @see AIQMessageBodyKey
 @see AIQMessageCreatedKey
 */
- (NSDictionary *)statusOfMessageWithId:(NSString *)identifier error:(NSError **)error;

/** Returns statuses of client originated message.
 
 This method can be used to retrieve a list of client originated message statuses dispatched to given destination.
 
 @param destination The name of the destination for which to retrieve a list of statuses. Must not be nil.
 @param processor Processor to be applied to raw message statuses before adding to the result array. If the
 processor sets an error passed as its argument, the whole call will fail with given error. Must not be nil.
 @param order Order in which to return messages.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the processing finished successfully, NO otherwise, in which case the error parameter will contain the
 reason of failure.
 
 @since 1.0.0
 @see AIQMessageOrder
 */
- (BOOL)statusesOfMessagesForDestination:(NSString *)destination
                               processor:(void (^)(NSDictionary *, NSError **))processor
                                   error:(NSError **)error;

@end

#endif /* AIQCoreLib_AIQMessaging_h */
