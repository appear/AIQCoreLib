#import <Foundation/Foundation.h>

@interface NSArray (AIQJSONSerializing)

- (NSString *)JSONString;
- (NSData *)JSONData;

@end

@interface NSDictionary (AIQJSONSerializing)

- (NSString *)JSONString;
- (NSData *)JSONData;

@end

@interface NSString (AIQJSONSerializing)

- (id)JSONObject;

@end

@interface NSData (AIQJSONSerializing)

- (id)JSONObject;

@end
