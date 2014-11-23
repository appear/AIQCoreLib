#ifndef AIQCoreLib_AIQSession_h
#define AIQCoreLib_AIQSession_h

#import <Foundation/Foundation.h>

@class AIQDataStore;
@class AIQSynchronization;

EXTERN_API(NSString *) const kAIQUserInfo;
EXTERN_API(NSString *) const kAIQUserEmail;
EXTERN_API(NSString *) const kAIQUserFullName;
EXTERN_API(NSString *) const kAIQUserGroups;
EXTERN_API(NSString *) const kAIQUserName;
EXTERN_API(NSString *) const kAIQUserPermissions;
EXTERN_API(NSString *) const kAIQUserProfile;
EXTERN_API(NSString *) const kAIQUserRoles;

@interface AIQSession : NSObject

+ (instancetype)currentSession;

+ (BOOL)canResume;
+ (instancetype)resume:(NSError **)error;
+ (instancetype)sessionWithBaseURL:(NSURL *)url;

- (void)openForUser:(NSString *)username
           password:(NSString *)password
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;

- (void)openForUser:(NSString *)username
           password:(NSString *)password
               info:(NSDictionary *)info
     inOrganization:(NSString *)organization
            success:(void (^)(void))success
            failure:(void (^)(NSError *error))failure;

- (void)close:(void (^)(void))success failure:(void (^)(NSError *error))failure;
- (void)cancel;

- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

- (AIQDataStore *)dataStoreForSolution:(NSString *)solution;
- (AIQSynchronization *)synchronization;

@end

#endif /* AIQCoreLib_AIQSession_h */