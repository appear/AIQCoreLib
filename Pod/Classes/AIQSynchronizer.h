#ifndef AIQCoreLib_AIQSynchronizer_h
#define AIQCoreLib_AIQSynchronizer_h

#import "AIQDataStore.h"

@protocol AIQSynchronizer <NSObject>

- (void)didCreateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didUpdateDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didDeleteDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;

- (void)didSynchronizeDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didRejectDocument:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason;
- (void)documentError:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status;

- (void)didCreateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didUpdateAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didDeleteAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;

- (void)didSynchronizeAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didRejectAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason;
- (void)attachmentError:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution errorCode:(NSInteger)code status:(AIQSynchronizationStatus)status;

- (void)willDownloadAttachment:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)attachmentDidBecomeAvailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)attachmentDidBecomeUnavailable:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)attachmentDidFail:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)attachmentDidProgress:(NSString *)name identifier:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution progress:(float)progress;

- (void)close;

@end


#endif
