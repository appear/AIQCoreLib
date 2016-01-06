#import <ifaddrs.h>
#import <arpa/inet.h>

#import "NSString+Helpers.h"

@implementation NSString (Helpers)

+ (NSString *)stringWithIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *interface = NULL;
    int success = 0;

    success = getifaddrs(&interfaces);
    if (success == 0) {
        interface = interfaces;
        while (interface != NULL) {
            if( interface->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:interface->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)interface->ifa_addr)->sin_addr)];
                }
            }

            interface = interface->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

- (NSString *)URLEncode {
    static CFStringRef _hxURLEscapeChars = CFSTR("￼=,!$&'()*+;@?\r\n\"<>#\t :/");
    return ((__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                  (__bridge CFStringRef)self,
                                                                                  NULL,
                                                                                  _hxURLEscapeChars,
                                                                                  kCFStringEncodingUTF8));
}

- (BOOL)isEmpty {
    return (self.length == 0) || ([self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0);
}

@end
