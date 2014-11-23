#import "AIQError.h"

NSString *const AIQErrorDomain = @"com.appearnetworks.aiq";

@implementation AIQError

+ (id)errorWithCode:(NSInteger)code userInfo:(NSDictionary *)dict {
    return [AIQError errorWithDomain:AIQErrorDomain code:code userInfo:dict];
}

+ (id)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [AIQError errorWithDomain:AIQErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
