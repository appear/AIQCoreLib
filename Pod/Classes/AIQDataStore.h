#import <Foundation/Foundation.h>

EXTERN_API(NSString *) const AIQGlobalSolution;

typedef NS_ENUM(NSUInteger, AIQSynchronizationStatus) {
    AIQSynchronizationStatusCreated,
    AIQSynchronizationStatusUpdated,
    AIQSynchronizationStatusDeleted,
    AIQSynchronizationStatusSynchronized,
    AIQSynchronizationStatusRejected
};

typedef NS_ENUM(NSUInteger, AIQAttachmentState) {
    AIQAttachmentStateAvailable,
    AIQAttachmentStateUnavailable,
    AIQAttachmentStateFailed
};

typedef NS_ENUM(NSUInteger, AIQRejectionReason) {
    AIQRejectionReasonUnknown,
    AIQRejectionReasonPermissionDenied,
    AIQRejectionReasonDocumentNotFound,
    AIQRejectionReasonTypeNotFound,
    AIQRejectionReasonRestrictedType,
    AIQRejectionReasonCreateConflict,
    AIQRejectionReasonUpdateConflict,
    AIQRejectionReasonLargeAttachment
};

EXTERN_API(NSString *) const kAIQDocumentId;
EXTERN_API(NSString *) const kAIQDocumentRejectionReason;
EXTERN_API(NSString *) const kAIQDocumentSynchronizationStatus;
EXTERN_API(NSString *) const kAIQDocumentType;

EXTERN_API(NSString *) const kAIQAttachmentContentType;
EXTERN_API(NSString *) const kAIQAttachmentName;
EXTERN_API(NSString *) const kAIQAttachmentRejectionReason;
EXTERN_API(NSString *) const kAIQAttachmentResourceUrl;
EXTERN_API(NSString *) const kAIQAttachmentSynchronizationStatus;
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

@end
