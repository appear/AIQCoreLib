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

#import <Foundation/Foundation.h>

EXTERN_API(NSString *) const AIQGlobalSolution;

/**
 This enumeration contains all possible synchronization statuses of business documents
 and their attachments.
 */
typedef NS_ENUM(NSUInteger, AIQSynchronizationStatus) {

    /**
     Document or attachment has been created locally and waits for the synchronization.
     */
    AIQSynchronizationStatusCreated,

    /**
     Document or attachment has been updated locally and waits for the synchronization.
     */
    AIQSynchronizationStatusUpdated,

    /**
     Document or attachment has been deleted locally and waits for the synchronization.
     */
    AIQSynchronizationStatusDeleted,

    /**
     Document or attachment has been successfully synchronized with the Mobility Platform.
     */
    AIQSynchronizationStatusSynchronized,

    /**
     Document or attachment has been rejected by the Mobility Platform.
     */
    AIQSynchronizationStatusRejected
};

/**
 This enumeration contains all possible attachment statuses.
 */
typedef NS_ENUM(NSUInteger, AIQAttachmentState) {

    /**
     Attachment is stored locally and ready to retrieve.
     */
    AIQAttachmentStateAvailable,

    /**
     Attachment failed to download but will be redownloaded with next synchronization.
     */
    AIQAttachmentStateUnavailable,

    /**
     Attachment is permanently missing and will not be redownloaded.
     */
    AIQAttachmentStateFailed
};

/**
 Enumeration of document and attachment rejection reasons.
 */
typedef NS_ENUM(NSUInteger, AIQRejectionReason) {

    /**
     Reason was not specified by the Mobility Platform.
     */
    AIQRejectionReasonUnknown,

    /**
     User does not have a permission to perform given action on attachments or documents
     of the given type.
     */
    AIQRejectionReasonPermissionDenied,

    /**
     Document for given identifier could not be found.
     */
    AIQRejectionReasonDocumentNotFound,

    /**
     Specified document type was not recognized.
     */
    AIQRejectionReasonTypeNotFound,

    /**
     Given document type cannot be created or modified from the client.
     */
    AIQRejectionReasonRestrictedType,

    /**
     Document identifier or attachment name already exists.
     */
    AIQRejectionReasonCreateConflict,

    /**
     Document or attachment revision does not match.
     */
    AIQRejectionReasonUpdateConflict,

    /**
     Attachment data is too long.
     */
    AIQRejectionReasonLargeAttachment
};

/** User info key for document identifier.

 This key is used to store an identifier of a business document stored within the AIQDataStore.
 It can be used to retrieve an identifier from business documents.

 @see documentExistsForId:error:
 @see documentForId:error:

 @note Document identifier is one of the system fields and can be neither created nor modified
 in any way by the client code.
 */
EXTERN_API(NSString *) const kAIQDocumentId;

/** User info key for document rejection reason.

 This key is used to store a rejection reason for documents which fail to synchronize.

 @since 1.3.0
 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQDocumentRejectionReason;

/** User info key for document status.

 This key is used to store a status of a document.

 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQDocumentSynchronizationStatus;

/** User info key for document type.

 This key is used to store a type of a business document stored within the AIQDataStore. It
 can be used to retrieve type of a business document.

 @note Document type is one of the system fields and can be neither created nor modified in
 any way by the client code.
 */
EXTERN_API(NSString *) const kAIQDocumentType;

/** User info key for attachment content type.

 This key is used to store a content type of an attachment. It doesn't have any special
 meaning but can be used as a filter field when retrieving a list of documents.

 @note Parent document identifier is one of the system fields and can be set only by
 creating an attachment using AIQDataStore module.
 */
EXTERN_API(NSString *) const kAIQAttachmentContentType;

/** User info key for attachment name.

 This key is used to store a name of an attachment. It can be used to retrieve the attachment 
 from the document.

 @note Attachment is one of the system fields and can be set only by creating an attachment
 using AIQDataStore module.
 */
EXTERN_API(NSString *) const kAIQAttachmentName;

/** User info key for attachment rejection reason.

 This key is used to store a rejection reason for attachments which fail to synchronize.

 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQAttachmentRejectionReason;

/** User info key for attachment status.

 This key is used to store a status of a document or an attachment.

 @see AIQSynchronizationStatus
 */
EXTERN_API(NSString *) const kAIQAttachmentSynchronizationStatus;

/** User info key for attachment state.

 This key is used to store an availability state of an attachment.

 @see AIQAttachmentState

 @warning Availability state is one of the system fields and can be neither set nor modified
 by the client code.
 */
EXTERN_API(NSString *) const kAIQAttachmentState;

@interface AIQDataStore : NSObject

- (void)documentTypes:(void (^)(NSString *type, NSError **error))processor
              failure:(void (^)(NSError *error))failure;

- (void)documentsOfType:(NSString *)type
              processor:(void (^)(NSDictionary *document, NSError **error))processor
                failure:(void (^)(NSError *error))failure;

- (void)documentWithId:(NSString *)identifier
               success:(void (^)(NSDictionary *document))success
               failure:(void (^)(NSError *error))failure;

- (void)createDocument:(NSDictionary *)fields
                ofType:(NSString *)type
               success:(void (^)(NSDictionary *document))success
               failure:(void (^)(NSError *error))failure;

- (void)updateFields:(NSDictionary *)fields
    ofDocumentWithId:(NSString *)identifier
             success:(void (^)(NSDictionary *document))success
             failure:(void (^)(NSError *error))failure;

- (void)deleteDocumentWithId:(NSString *)identifier
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *error))failure;

@end
