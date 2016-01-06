#import <Foundation/Foundation.h>

@interface NSDictionary (AIQAttachment)

- (NSString *)name;
- (NSString *)contentType;
- (BOOL)isAvailable;
- (BOOL)isFailed;
- (BOOL)isLaunchable;

@end
