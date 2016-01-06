#import "AIQError.h"

NSString *const AIQErrorDomain = @"com.appearnetworks.aiq";

@implementation AIQError

+ (id)errorWithCode:(NSInteger)code userInfo:(NSDictionary *)dict {
    return [AIQError errorWithDomain:AIQErrorDomain code:code userInfo:dict];
}

+ (id)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [AIQError errorWithDomain:AIQErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message ? message : @""}];
}

- (NSString *)description {
    NSString *name;
    switch (self.code) {
        case AIQErrorIdNotFound:
            name = @"AIQIdNotFound";
            break;
        case AIQErrorNameNotFound:
            name = @"AIQNameNotFound";
            break;
        case AIQErrorResourceNotFound:
            name = @"AIQResourceNotFound";
            break;
        case AIQErrorInvalidArgument:
            name = @"AIQErrorInvalidArgument";
            break;
        case AIQErrorConnectionFault:
            name = @"AIQErrorConnectionFault";
            break;
        case AIQErrorContainerFault:
            name = @"AIQErrorContainerFault";
            break;
        case AIQErrorUnauthorized:
            name = @"AIQUnauthorized";
            break;
        default:
            name = [NSString stringWithFormat:@"AIQError no %ld", (long)self.code];
    }
    return [NSString stringWithFormat:@"<%@: %@>", name, self.userInfo[NSLocalizedDescriptionKey]];
}

@end
