#ifndef AIQCoreLib_AIQError_h
#define AIQCoreLib_AIQError_h

#import <Foundation/Foundation.h>

EXTERN_API(NSString *) const AIQErrorDomain;

enum {
    AIQErrorIdNotFound       = 1,
    AIQErrorNameNotFound     = 2,
    AIQErrorResourceNotFound = 3,
    AIQErrorInvalidArgument  = 4,
    AIQErrorConnectionFault  = 5,
    AIQErrorContainerFault   = 6,
    AIQErrorUnauthorized     = 8
};

@interface AIQError : NSError

+ (id)errorWithCode:(NSInteger)code userInfo:(NSDictionary *)dict;
+ (id)errorWithCode:(NSInteger)code message:(NSString *)message;

@end

#endif /* AIQCoreLib_AIQError_h */
