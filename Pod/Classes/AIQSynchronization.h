#ifndef AIQCoreLib_AIQSynchronization_h
#define AIQCoreLib_AIQSynchronization_h

#import <Foundation/Foundation.h>

EXTERN_API(NSString *) const AIQDidCreateDocumentNotification;
EXTERN_API(NSString *) const AIQDidUpdateDocumentNotification;
EXTERN_API(NSString *) const AIQDidDeleteDocumentNotification;

EXTERN_API(NSString *) const AIQDidCreateAttachmentNotification;
EXTERN_API(NSString *) const AIQDidUpdateAttachmentNotification;
EXTERN_API(NSString *) const AIQDidDeleteAttachmentNotification;

EXTERN_API(NSString *) const AIQAttachmentDidBecomeAvailableNotification;
EXTERN_API(NSString *) const AIQAttachmentDidBecomeUnavailableNotification;
EXTERN_API(NSString *) const AIQAttachmentDidBecomeFailedNotification;

EXTERN_API(NSString *) const AIQDocumentIdUserInfoKey;
EXTERN_API(NSString *) const AIQDocumentTypeUserInfoKey;
EXTERN_API(NSString *) const AIQAttachmentNameUserInfoKey;

EXTERN_API(NSString *) const AIQSolutionUserInfoKey;

@interface AIQSynchronization : NSObject

- (void)synchronize:(void (^)(void))success failure:(void (^)(NSError *error))failure;

- (void)cancel;

@end

#endif /* AIQCoreLib_AIQSynchronization_h */