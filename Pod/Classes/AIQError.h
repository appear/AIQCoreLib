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

#ifndef AIQCoreLib_AIQError_h
#define AIQCoreLib_AIQError_h

#import <Foundation/Foundation.h>

/**
 Default error domain for errors triggered by the AIQ Core API.
 */
EXTERN_API(NSString *) const AIQErrorDomain;

enum {

    /**
     This error is triggered when trying to retrieve entities recognizable by
     their identifiers:

     - Business documents
     - Local documents
     - Client originated messages
     - Server originated messages
     */
    AIQErrorIdNotFound,

    /**
     This error is triggered when trying to retrieve entities recognizable by 
     their names:

     - Attachments of business documents
     - Attachments of local documents
     - Attachments of server originated messages
     */
    AIQErrorNameNotFound,

    /**
     This error is triggered when trying to retrieve entities recognizable by
     their resource URLs:

     - Attachment contents of business documents
     - Attachment contents of local documents
     - Attachment contents of server originated messages
     */
    AIQErrorResourceNotFound,

    /**
     This error is generated in case when arguments passed to Core API methods
     are invalid or unacceptable, for example when business document identifier
     is not a string or attachment descriptor does not contain one of the
     required fields. It can be used to capture user errors.
     */
    AIQErrorInvalidArgument,

    /**
     This error is generated in case when the Mobility Platform has ended the
     session of the current user. User has to be reauthenticated in order to
     proceed.
     */
    AIQErrorUnauthorized,

    /**
     This error is generated in case the Mobility Platform has ended the
     synchronization session. Synchronization has to be restarted in order to
     proceed.
     */
    AIQErrorGone,

    /**
     This error is generated in case when one of the underlying layers (like
     database or disk storage) fails. This usually means that the application
     has to be restarted in order to proceed.
     */
    AIQErrorContainerFault
};

/**
 Class representing errors triggered by the AIQ Core API.
 */
@interface AIQError : NSError

/**
 Creates a new instance of AIQError with given error code and error
 message.

 @param code Error code.
 @param message Error message. May be nil.
 @return New instance of AIQError. Will not be nil.
 */
+ (id)errorWithCode:(NSInteger)code message:(NSString *)message;

/**
 Creates a new instance of AIQError with given error code and user info 
 dictionary.
 
 @param code Error code.
 @param dict User info dictionary. May be nil.
 @return New instance of AIQError. Will not be nil.
 */
+ (id)errorWithCode:(NSInteger)code userInfo:(NSDictionary *)dict;

@end

#endif /* AIQCoreLib_AIQError_h */