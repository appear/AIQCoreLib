#import <Foundation/Foundation.h>

#if	TARGET_OS_IPHONE
    #import <UIKit/UIDevice.h>
#endif

#import "AIQCoreLibInternal.h"
#import "DeviceContextProvider.h"

@implementation DeviceContextProvider

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return ![key isEqualToString:@"data"];
}

- (id)init {
    self = [super init];
    if (self) {
        [self willChangeValueForKey:@"data"];
        _data = [NSMutableDictionary dictionary];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *root = [defaults dictionaryForKey:@"AIQCoreLib"];

        ((NSMutableDictionary *)_data)[@"id"] = root[@"deviceId"];
        ((NSMutableDictionary *)_data)[@"clientLibVersion"] = [AIQCoreLibInternal clientLibVersion];
#if TARGET_OS_IPHONE
        NSString *clientVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
        if (clientVersion) {
            ((NSMutableDictionary *)_data)[@"clientVersion"] = clientVersion;
        }
        ((NSMutableDictionary *)_data)[@"os"] = @"iOS";
        ((NSMutableDictionary *)_data)[@"osVersion"] = [UIDevice currentDevice].systemVersion;

        Class jsBridgeClass = NSClassFromString(@"AIQJSBridgeInternal");
        if (jsBridgeClass) {
            SEL selector = NSSelectorFromString(@"apiLevel");
            NSMethodSignature *signature = [jsBridgeClass methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [invocation setTarget:jsBridgeClass];
            [invocation invoke];
            NSUInteger jsApiLevel;
            [invocation getReturnValue:&jsApiLevel];
            ((NSMutableDictionary *)_data)[@"jsApiLevel"] = @(jsApiLevel);
        }
#else
        ((NSMutableDictionary *)_data)[@"os"] = @"Mac";
        ((NSMutableDictionary *)_data)[@"osVersion"] = [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
        [self didChangeValueForKey:@"data"];
    }
    return self;
}

- (NSString *)getName {
    return @"com.appearnetworks.aiq.device";
}

@end
