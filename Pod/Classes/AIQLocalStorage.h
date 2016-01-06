#ifndef AIQCoreLib_AIQLocalStorage_h
#define AIQCoreLib_AIQLocalStorage_h

#import <Foundation/Foundation.h>

/*!
 @header AIQLocalStorage.h
 @author Marcin Lukow
 @copyright 2013 Appear Networks Systems AB
 @updated 2014-02-04
 @brief Local Storage module can be used to store documents locally, without synchronizing them to the backend.
 @version 1.0.2
 */

/** AIQLocalStorage module.

 AIQLocalStorage module can be used to store documents locally, without synchronizing them to the backend.

 @since 1.0.0
 */
@interface AIQLocalStorage : NSObject

- (void)close;

/**---------------------------------------------------------------------------------------
 * @name Document management
 * ---------------------------------------------------------------------------------------
 */

/** Tells whether a document with given identifier exists.

 This method can be used to check if a document with given identifier exists in the local storage. This
 method is failsafe so it will return NO in case of any error.

 @param identifier Identifier of a document for which to check the existence. Must not be nil.
 @return YES if document with given identifier exists, NO otherwise or in case of any errors.
 @since 1.0.0
 */
- (BOOL)documentExistsWithId:(NSString *)identifier;

/** Returns a document for given identifier.

 This method can be used to retrieve a document by its identifier.

 @param identifier Identifier of a document to retrieve. Must not be nil and must exist in the local storage.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Document for given identifier or nil if the document could not be found or if retrieving failed, in which
 case the error parameter will contain the reason of failure.
 @since 1.0.0
 */
- (NSDictionary *)documentForId:(NSString *)identifier error:(NSError **)error;

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
 @return Updated document or nil if creation failed, in which case the error parameter will contain the reason of
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
 @since 1.0.2
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
 @since 1.0.2
 */
- (NSDictionary *)attachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier error:(NSError **)error;

/** Returns all attachments for a document with given identifier.

 This method can be used to retrieve a list of attachments belonging to a document with given identifier.

 @param identifier Identifier of a document for which to retrieve the attachments. Must not be nil and must exist in
 the data store.
 @param error If defined, will store an error in case of any failures. May be nil.
 @return Array of attachments for a document with given identifier. May be empty if the document has no attachments
 or nil if the retrieving failed, in which case the error parameter will contain the reason of failure.
 @since 1.0.2
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
 @since 1.0.2
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
 @return Updated attachment or nil if the creation failed, in which case the error parameter will contain the
 reason of failure.
 @since 1.0.2
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
 @since 1.0.2
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

@end

#endif /* AIQCoreLib_AIQLocalStorage_h */
