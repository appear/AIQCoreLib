#ifndef AIQCoreLib_SynchronizationReceiver_h
#define AIQCoreLib_SynchronizationReceiver_h

#import <Foundation/Foundation.h>

@protocol SynchronizationReceiver

- (void)didCreateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didUpdateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didDeleteDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;

- (void)didCreateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didUpdateAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didDeleteAttachmentWithName:(NSString *)name forDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didProgressAttachmentWithName:(NSString *)name
                           downloaded:(unsigned long long)downloadedBytes
                                total:(unsigned long long)totalBytes
                    forDocumentWithId:(NSString *)identifier
                                 type:(NSString *)type
                             solution:(NSString *)solution;
- (void)didChangeState:(AIQAttachmentState)state
  ofAttachmentWithName:(NSString *)name
     forDocumentWithId:(NSString *)identifier
                  type:(NSString *)type
              solution:(NSString *)solution;

@end

#endif /* AIQCoreLib_SynchronizationReceiver_h */