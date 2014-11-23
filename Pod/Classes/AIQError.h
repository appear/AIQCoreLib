#ifndef AIQCoreLib_AIQError_h
#define AIQCoreLib_AIQError_h

#import <Foundation/Foundation.h>

EXTERN_API(NSString *) const AIQErrorDomain;

enum {
    AIQErrorIdNotFound,
    AIQErrorNameNotFound,
    AIQErrorResourceNotFound,
    AIQErrorInvalidArgument,
    AIQErrorUnauthorized,
    AIQErrorGone,
    AIQErrorContainerFault
};

@interface AIQError : NSError

+ (id)errorWithCode:(NSInteger)code userInfo:(NSDictionary *)dict;
+ (id)errorWithCode:(NSInteger)code message:(NSString *)message;

@end

#endif /* AIQCoreLib_AIQError_h */