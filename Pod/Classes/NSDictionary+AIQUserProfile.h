#import <Foundation/Foundation.h>

@interface NSDictionary (AIQUserProfile)

- (NSString *)identifier;
- (NSString *)username;
- (NSString *)email;
- (NSString *)fullName;
- (NSDictionary *)profile;
- (NSArray *)roles;
- (NSArray *)groups;
- (NSArray *)permissions;

@end
