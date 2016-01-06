#import "NSURL+Helpers.h"

@implementation NSURL (Helpers)

- (NSDictionary *)queryAsDictionary {
    NSArray *params = [self.query componentsSeparatedByString:@"&"];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:params.count];
    for (NSString *param in params) {
        NSArray *pair = [param componentsSeparatedByString:@"="];
        if (pair.count > 1) {
            result[pair[0]] = pair[1];
        }
    }
    return result;
}

@end
