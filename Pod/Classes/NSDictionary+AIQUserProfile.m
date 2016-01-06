#import "AIQSession.h"
#import "NSDictionary+AIQUserProfile.h"

@implementation NSDictionary (AIQUserProfile)

- (NSString *)identifier {
    return self[kAIQUserId];
}

- (NSString *)username {
    return self[kAIQUserName];
}

- (NSString *)email {
    return self[kAIQUserEmail];
}

- (NSString *)fullName {
    return self[kAIQUserFullName];
}

- (NSDictionary *)profile {
    return self[kAIQUserProfile];
}

- (NSArray *)roles {
    return self[kAIQUserRoles];
}

- (NSArray *)groups {
    return self[kAIQUserGroups];
}

- (NSArray *)permissions {
    return self[kAIQUserPermissions];
}

@end
