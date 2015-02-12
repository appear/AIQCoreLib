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

#ifndef AIQCoreLib_SynchronizationReceiver_h
#define AIQCoreLib_SynchronizationReceiver_h

#import <Foundation/Foundation.h>

@protocol SynchronizationReceiver

- (void)didCreateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didUpdateDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didDeleteDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didSynchronizeDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution;
- (void)didRejectDocumentWithId:(NSString *)identifier type:(NSString *)type solution:(NSString *)solution reason:(AIQRejectionReason)reason;

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