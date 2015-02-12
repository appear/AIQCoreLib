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

#ifndef AIQCoreLib_AIQSynchronization_h
#define AIQCoreLib_AIQSynchronization_h

#import <Foundation/Foundation.h>

/**
 Notifies that a business document has been created remotely.
 
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidCreateDocumentNotification;

/**
 Notifies that a business document has been updated remotely.

 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidUpdateDocumentNotification;

/**
 Notifies that a business document has been deleted remotely.

 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidDeleteDocumentNotification;

/**
 Notifies that a local change to a business document has been successfully
 synchronized with the Mobility Platform.

 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidSynchronizeDocumentNotification;

/**
 Notifies that a local change to a business document has been rejected by
 the Mobility Platform.
 
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 @see AIQRejectionReasonUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidRejectDocumentNotification;

/**
 Notifies that an attachment of a business document has been created 
 remotely.
 
 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidCreateAttachmentNotification;

/**
 Notifies that an attachment of a business document has been updated
 remotely.

 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidUpdateAttachmentNotification;

/**
 Notifies that an attachment of a business document has been deleted
 remotely.

 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQDidDeleteAttachmentNotification;

/**
 Notifies that the contents of an attachment has become available.

 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQAttachmentDidBecomeAvailableNotification;

/**
 Notifies that the contents of an attachment has become unavailable.

 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQAttachmentDidBecomeUnavailableNotification;

/**
 Notifies that the download of an attachment failed and the contents will
 not be downloaded until the Mobility Platform provides a new revision.

 @see AIQAttachmentNameUserInfoKey
 @see AIQDocumentIdUserInfoKey
 @see AIQDocumentTypeUserInfoKey
 @see AIQSolutionUserInfoKey
 */
EXTERN_API(NSString *) const AIQAttachmentDidBecomeFailedNotification;

/**
 User info key which can be used to retrieve the document identifier from
 a notification.
 
 @see AIQDidCreateDocumentNotification
 @see AIQDidUpdateDocumentNotification
 @see AIQDidDeleteDocumentNotification
 @see AIQDidSynchronizeDocumentNotification
 @see AIQDidRejectDocumentNotification
 @see AIQDidCreateAttachmentNotification
 @see AIQDidUpdateAttachmentNotification
 @see AIQDidDeleteAttachmentNotification
 @see AIQAttachmentDidBecomeAvailableNotification
 @see AIQAttachmentDidBecomeUnavailableNotification
 @see AIQAttachmentDidBecomeFailedNotification
 */
EXTERN_API(NSString *) const AIQDocumentIdUserInfoKey;

/**
 User info key which can be used to retrieve the document type from a
 notification.

 @see AIQDidCreateDocumentNotification
 @see AIQDidUpdateDocumentNotification
 @see AIQDidDeleteDocumentNotification
 @see AIQDidSynchronizeDocumentNotification
 @see AIQDidRejectDocumentNotification
 @see AIQDidCreateAttachmentNotification
 @see AIQDidUpdateAttachmentNotification
 @see AIQDidDeleteAttachmentNotification
 @see AIQAttachmentDidBecomeAvailableNotification
 @see AIQAttachmentDidBecomeUnavailableNotification
 @see AIQAttachmentDidBecomeFailedNotification
 */
EXTERN_API(NSString *) const AIQDocumentTypeUserInfoKey;

/**
 User info key which can be used to retrieve the attachment name from a
 notification.

 @see AIQDidCreateAttachmentNotification
 @see AIQDidUpdateAttachmentNotification
 @see AIQDidDeleteAttachmentNotification
 @see AIQAttachmentDidBecomeAvailableNotification
 @see AIQAttachmentDidBecomeUnavailableNotification
 @see AIQAttachmentDidBecomeFailedNotification
 */
EXTERN_API(NSString *) const AIQAttachmentNameUserInfoKey;

/**
 User info key which can be used to retrieve the solution name from a
 notification.

 @see AIQDidCreateDocumentNotification
 @see AIQDidUpdateDocumentNotification
 @see AIQDidDeleteDocumentNotification
 @see AIQDidSynchronizeDocumentNotification
 @see AIQDidRejectDocumentNotification
 @see AIQDidCreateAttachmentNotification
 @see AIQDidUpdateAttachmentNotification
 @see AIQDidDeleteAttachmentNotification
 @see AIQAttachmentDidBecomeAvailableNotification
 @see AIQAttachmentDidBecomeUnavailableNotification
 @see AIQAttachmentDidBecomeFailedNotification
 */
EXTERN_API(NSString *) const AIQSolutionUserInfoKey;

/**
 User info key which can be used to retieve the rejection reason from a
 notification.

 @see AIQDidRejectDocumentNotification
 */
EXTERN_API(NSString *) const AIQRejectionReasonUserInfoKey;

/**
 A class that allows to to synchronize the business data with the Mobility
 Platform.
 */
@interface AIQSynchronization : NSObject

/**
 Performs the synchronization with the Mobility Platform.
 
 @param success Callback executed when the synchronization has been successful.
 May be nil.
 @param failure Callback executed when the synchronization has failed. Will 
 receive an instance of NSError storing the cause of the error as a sole 
 argument. Can be nil.
 */
- (void)synchronize:(void (^)(void))success failure:(void (^)(NSError *error))failure;

/**
 Cancells the ongoing synchronization. Does nothing if the synchronization is
 not running.
 */
- (void)cancel;

@end

#endif /* AIQCoreLib_AIQSynchronization_h */