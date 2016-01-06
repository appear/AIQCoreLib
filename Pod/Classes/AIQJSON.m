#import <Foundation/NSJSONSerialization.h>

#import "AIQJSON.h"
#import "AIQLog.h"

@implementation NSArray (AIQJSONSerializing)

- (NSString *)JSONString {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:kNilOptions error:&error];

    if (error != nil) {
        AIQLogCError(1, @"Failed to serialize JSON: %@", error.localizedDescription);
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSData *)JSONData {
    return [NSJSONSerialization dataWithJSONObject:self options:kNilOptions error:nil];
}

@end

@implementation NSDictionary (AIQJSONSerializing)

- (NSString *)JSONString {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:kNilOptions error:&error];

    if (error != nil) {
        AIQLogCError(1, @"Failed to serialize JSON: %@", error.localizedDescription);
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSData *)JSONData {
    return [NSJSONSerialization dataWithJSONObject:self options:kNilOptions error:nil];
}

@end

@implementation NSString (AIQJSONSerializing)

- (id)JSONObject {
    return [[self dataUsingEncoding:NSUTF8StringEncoding] JSONObject];
}

@end

@implementation NSData (AIQJSONSerializing)

- (id)JSONObject {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:self options:NSJSONReadingMutableContainers error:&error];

    if (error != nil) {
        AIQLogCError(1, @"Failed to parse JSON: %@", error.localizedDescription);
        return nil;
    }

    return object;
}

@end
