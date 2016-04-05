#ifndef AIQCoreLib_AIQDataStore_h
#define AIQCoreLib_AIQDataStore_h

#import <Foundation/Foundation.h>

/*!
 @header AIQDataStore.h
 @author Marcin Lukow, Simon Jarbrant
 @copyright 2014 Appear Networks Systems AB
 @updated 2016-04-05
 @brief Data Store module can be used to access business documents stored in the document storage.
 @version 1.3.1
 */

@class AIQDataStore;
@class AIQSession;

/**
 This enumeration contains all possible attachment statuses.
 
 @since 1.0.0
 */
typedef NS_ENUM(NSInteger, AIQAttachmentState) {
    /** Attachment is stored locally and ready to retrieve.
     
     @since 1.0.0
     */
    AIQAttachmentStateAvailable,
    
    /** Attachment failed to download but will be redownloaded with next synchronization.
     
     @since 1.0.0
     */
    AIQAttachmentStateUnavailable,
    
    /** Attachment is permanently missing and will not be redownloaded.
     
     @since 1.0.0
     */
    AIQAttachmentStateFailed
};

/**
 This enumeration contains all possible document statuses.
 
 @since 1.3.0
 */
typedef NS_ENUM(NSInteger, AIQSynchronizationStatus) {
    
    /** Document or attachment has been successfully synchronized with the AIQ Server.
     
     @since 1.3.0
     */
    AIQSynchronizationStatusSynchronized,
    
    /** Document or attachment has been deleted locally and waits for the synchronization.
     
     @since 1.3.0
     */
    AIQSynchronizationStatusDeleted,
    
    /** Document or attachment has been created locally and waits for the synchronization.
     
     @since 1.3.0
     */
    AIQSynchronizationStatusCreated,
    
    /** Document or attachment has been updated locally and waits for the synchronization.
     
     @since 1.3.0
     */
    AIQSynchronizationStatusUpdated,
    
    /** Document or attachment has been rejected by the AIQ Server.
     
     @since 1.3.0
     */
    AIQSynchronizationStatusRejected
};

/** Enumeration of document and attachment rejection reasons.
 
 This enumeration contains all possible rejection reasons.
 
 @since 1.0.0
 */
typedef NS_ENUM(NSInteger, AIQRejectionReason) {
    
    /** Reason was not specified by the backend.
     
     @since 1.0.0
     */
    AIQRejectionReasonUnknown,
    
    /** User does not have a permission to perform given action on attachments or documents of the given type.
     
     @since 1.0.0
     */
    AIQRejectionReasonPermissionDenied,
    
    /** Document for given identifier could not be found.
     
     @since 1.0.0
     */
    AIQRejectionReasonDocumentNotFound,
    
    /** Specified document type was not recognized.
     
     @since 1.0.0
     */
    AIQRejectionReasonTypeNotFound,
    
    /** Given document type cannot be created or modified from the client.
     
     @since 1.0.0
     */
    AIQRejectionReasonRestrictedType,
    
    /** Document identifier or attachment name already exists.
     
     @since 1.0.0
     */
    AIQRejectionReasonCreateConflict,
    
    /** Document or attachment revision does not match.
     
     @since 1.0.0
     */
    AIQRejectionReasonUpdateConflict,
    
    /** Attachment data is too long.
     
     @since 1.0.0
     */
    AIQRejectionReasonLargeAttachment
};

/** User info key for document identifier.
 
 This key is used to store an identifier of a business document stored within the AIQDataStore. It can be
 used to retrieve an identifier from business documents.
 
 @since 1.0.0
 @see documentExistsForId:error:
 @see documentForId:error:
 
 @warning Document identifier is one of the system fields and can be neither created nor modified in any way by the client code.
 */
EXTERN_API(NSString *) const kAIQDocumentId;

/** User info key for document type.
 
 This key is used to store a type of a business document stored within the AIQDataStore. It can be used to
 retrieve type of a business document.
 
 @since 1.0.0
 @see documentsOfType:processor:error:
 @see createDocumentOfType:withFields:error:
 
 @warning Document type is one of the system fields and can be neither created nor modified in any way by the client code.
 */
EXTERN_API(NSString *) const kAIQDocumentType;

EXTERN_API(NSString *) const kAIQDocumentRevision;

EXTERN_API(NSString *) const kAIQDocumentLaunchableId;

/** User info key for document status.
 
 This key is used to store a status of a document.
 
 @since 1.3.0
 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQDocumentStatus;

/** User info key for document rejection reason.
 
 This key is used to store a rejection reason for documents which fail to synchronize.
 
 @since 1.3.0
 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQDocumentRejectionReason;

/** User info key for attachment name.
 
 This key is used to store a name of an attachment. It can be used to retrieve the attachment from the
 document.
 
 @since 1.0.0
 @see attachmentWithName:existsForDocumentWithId:
 @see attachmentWithName:forDocumentWithId:error:
 @see createAttachmentWithName:contentType:andData:forDocumentWithId:error:
 @see deleteAttachmentWithName:fromDocumentWithId:error:
 @see dataForAttachmentWithName:fromDocumentWithId:error:
 
 @warning Attachment is one of the system fields and can be set only by creating an attachment using AIQDataStore module.
 */
EXTERN_API(NSString *) const kAIQAttachmentName;

/** User info key for attachment content type.
 
 This key is used to store a content type of an attachment. It doesn't have any special meaning but can be
 used as a filter field when retrieving a list of documents.
 
 @since 1.0.0
 @see createAttachmentWithName:contentType:andData:forDocumentWithId:error:
 @see updateData:withContentType:forAttachmentWithName:fromDocumentWithId:error:
 
 @warning Parent document identifier is one of the system fields and can be set only by creating an attachment using AIQDataStore
 module.
 */
EXTERN_API(NSString *) const kAIQAttachmentContentType;

EXTERN_API(NSString *)const kAIQAttachmentRevision;

/** User info key for attachment status.
 
 This key is used to store a status of a document or an attachment.
 
 @since 1.3.0
 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQAttachmentStatus;

/** User info key for attachment state.
 
 This key is used to store an availability state of an attachment.
 
 @since 1.0.0
 @see AIQAttachmentState
 
 @warning Availability state is one of the system fields and can be neither set nor modified by the client code.
 */
EXTERN_API(NSString *) const kAIQAttachmentState;

/** User info key for attachment rejection reason.
 
 This key is used to store a rejection reason for attachments which fail to synchronize.
 
 @since 1.3.0
 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQAttachmentRejectionReason;

/** AIQDataStore module.
 
 AIQDataStore module can be used to access documents synchronized by the AIQSynchronization part.
 
 @since 1.0.0
 @see AIQSynchronization
 */
@interface AIQDataStore : NSObject

/**---------------------------------------------------------------------------------------
 * @name Document management
 * ---------------------------------------------------------------------------------------
 */

/** Tells whether a document with given identifier exists.
 
 This method can be used to check if a document with given identifier exists in the data store. This
 method is failsafe so it will return NO in case of any error.
 
 @param identifier Identifier of a document for which to check the existence. Must not be nil.
 @return YES if document with given identifier exists, NO otherwise or in case of any errors.
 @since 1.0.0
 */
- (BOOL)documentExistsWithId:(NSString *)identifier;

/** Returns a document for given identifier.
 
 This method can be used to retrieve a document by its identifier.
 
 @param identifier Identifier of a document to retrieve. Must not be nil and must exist in the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Document for given identifier or nil if the document could not be found or if retrieving failed, in which
 case the error parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSDictionary *)documentForId:(NSString *)identifier error:(NSError **)error;

- (BOOL)documentTypes:(void (^)(NSString *, NSError **))processor error:(NSError **)error;

/** Processes documents of given type with given owner.
 
 This method can be used to retrieve a list of documents identified by given document type and belonging to
 a business document identified by given identifier.
 
 @param type Type of business documents to retrieve. Must not be nil.
 @param processor Processor to be applied to raw business documents before adding to the result array. If the
 processor sets an error passed as its argument, the whole call will fail with given error. Must not be nil.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the processing finished successfully, NO otherwise, in which case the error parameter will contain the
 reason of failure.
 @since 1.0.0
 */
- (BOOL)documentsOfType:(NSString *)type
              processor:(void (^)(NSDictionary *, NSError **))processor
                  error:(NSError **)error;

/** Creates a new document of given type with given fields.
 
 This method can be used to create a new document of given type and containing given fields.
 
 @param type Type of a document to create. Must not be nil.
 @param fields Dictionary containing fields to define for the new document. Must not be nil.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Newly created document or nil if creation failed, in which case the error parameter will contain the reason of
 failure.
 @since 1.0.0
 
 @warning If the field dictionary contains any of the system fields, these fields will be filtered out.
 */
- (NSDictionary *)createDocumentOfType:(NSString *)type withFields:(NSDictionary *)fields error:(NSError **)error;

/** Updates fields for a document identified by given identifier.
 
 This method can be used to update fields of a document identified by given identifier.
 
 @param fields Dictionary containing new fields for the document. Must not be nil.
 @param identifier Identifier of a document for which to update the fields. Must not be nil and must exist.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Updated document or nil if update failed, in which case the error parameter will contain the reason of
 failure.
 @since 1.0.0
 
 @warning If the field dictionary contains any of the system fields, these fields will be filtered out.
 
 @warning Updated document will only contain fields defined in the new field dictionary. If any of the existing fields are not
 defined in the new field dictionary, they will be removed from the document.
 */
- (NSDictionary *)updateFields:(NSDictionary *)fields forDocumentWithId:(NSString *)identifier error:(NSError **)error;

/** Deletes a document identified by given identifier.
 
 This method can be used to delete a document identified by given identifier.
 
 @param identifier Identifier of a document to remove. Must not be nil and must exist.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the document was successfully deleted, NO otherwise, in which case the error parameter will contain the
 reason of failure.
 @since 1.0.0
 */
- (BOOL)deleteDocumentWithId:(NSString *)identifier error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Attachment management
 * ---------------------------------------------------------------------------------------
 */

/** Tells whether an attachment with given name exists for a document with given identifier.
 
 This method can be used to check if an attachment with given name exists for a document with given
 identifier. This method is failsafe so it will return NO in case of any error.
 
 @param name Name of the attachment for which to check the existence. Must not be nil.
 @param identifier Identifier of a document for which to check the existence. Must not be nil.
 @return YES if attachment with given identifier exists, NO otherwise or in case of any errors.
 @since 1.0.0
 */
- (BOOL)attachmentWithName:(NSString *)name existsForDocumentWithId:(NSString *)identifier;

/** Returns an attachment for given name and document identifier.
 
 This method can be used to retrieve an attachment with given name for a document with given identifier.
 
 @param name Name of an attachment to retrieve. Must not be nil and must exist in the data store.
 @param identifier Identifier of a document for which to retrieve the attachment. Must not be nil and must exist in
 the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Attachment for given name and document identifier or nil if the attachment could not be found or if retrieving
 failed, in which case the error parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSDictionary *)attachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier error:(NSError **)error;

- (BOOL)attachmentsForDocumentWithId:(NSString *)identifier
                           processor:(void (^)(NSDictionary *, NSError **))processor
                               error:(NSError **)error;

/** Processes attachments for a document with given identifier.
 
 This method can be used to retrieve a list of attachments belonging to a document with given identifier.
 
 @param identifier Identifier of a document for which to retrieve the attachments. Must not be nil and must exist in
 the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return An array of attachment descriptors. May be nil if the attachments could not be retrieved, in which case the
 error parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSArray *)attachmentsForDocumentWithId:(NSString *)identifier error:(NSError **)error;

/** Creates an attachment for a document with given identifier.
 
 This method can be used to create an attachment with given name, content type and data for a document with
 given identifier.
 
 @param name Name of an attachment to create. Must not be nil and must not exist for a document with given identifier.
 @param contentType Content type of an attachment to create. Must not be nil.
 @param data Data for an attachment to create. Must not be nil.
 @param identifier Identifier of a document for which to create an attachment. Must not be nil and must identify an
 existing document.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Newly created attachment or nil if the creation failed, in which case the error parameter will contain the
 reason of failure.
 @since 1.0.0
 */
- (NSDictionary *)createAttachmentWithName:(NSString *)name
                               contentType:(NSString *)contentType
                                   andData:(NSData *)data
                         forDocumentWithId:(NSString *)identifier
                                     error:(NSError **)error;

/** Updates an attachment for a document with given identifier.
 
 This method can be used to update the data for an attachment with given name belonging to a document with
 given identifier.
 
 @param data New data for the attachment. Must not be nil.
 @param contentType Content type of an attachment to update. Must not be nil.
 @param name Name of the attachment to update. Must not be nil and must exist identify an existing attachment for a
 document with given identifier.
 @param identifier Identifier of a document for which to delete an attachment. Must not be nil and must identify an
 existing document.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Updated attachment or nil if the update failed, in which case the error parameter will contain the
 reason of failure.
 @since 1.0.0
 */
- (NSDictionary *)updateData:(NSData *)data
             withContentType:(NSString *)contentType
       forAttachmentWithName:(NSString *)name
          fromDocumentWithId:(NSString *)identifier
                       error:(NSError **)error;

/** Deletes an attachment from document with given identifier.
 
 This method can be used to delete an attachment from a document with given identifier.
 
 @param name Name of an attachment to delete. Must not be nil and must identify an existing attachment for a document
 with given identifier.
 @param identifier Identifier of a document for which to delete an attachment. Must not be nil and must identify an
 existing document.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return YES if the deletion succeeded and NO otherwise, in which case the error parameter will contain the reason
 of failure.
 @since 1.0.0
 */
- (BOOL)deleteAttachmentWithName:(NSString *)name fromDocumentWithId:(NSString *)identifier error:(NSError **)error;

/**---------------------------------------------------------------------------------------
 * @name Data management
 * ---------------------------------------------------------------------------------------
 */

/** Retrieves the data for given resource identifier.
 
 This method can be used to retrieve the data for given resource identifier.
 
 @param name Name of the attachment for which to return the data. Must not be nil and must exist in the data store.
 @param identifier Document identifier for which to return the data. Must not be nil and must exist in the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Data for given attachment or nil if the data does not exist or if retrieving failed, in which case the error
 parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSData *)dataForAttachmentWithName:(NSString *)name fromDocumentWithId:(NSString *)identifier error:(NSError **)error;

/** Retrieves the data for given file path.

 This method can be used to retrieve the data for the given file path.

 @param path Path to the attachment file on local storage. Must not be nil and must exist in the data store
 @return Data for given attachment or nil if the data does not exist
 @since 1.3.1
 */
- (NSData *)dataForAttachmentAtPath:(NSString *)path;

- (BOOL)hasUnsynchronizedDocumentsOfType:(NSString *)type;

- (void)close;

@end

#endif /* AIQCoreLib_AIQDataStore_h */
