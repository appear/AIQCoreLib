#import <Foundation/Foundation.h>

@interface AIQLaunchableStore : NSObject

EXTERN_API(NSString *) const AIQDidInstallLaunchableNotification;
EXTERN_API(NSString *) const AIQDidUninstallLaunchableNotification;
EXTERN_API(NSString *) const AIQDidUpdateLaunchableNotification;

EXTERN_API(NSString *) const AIQWillDownloadLaunchableNotification;
EXTERN_API(NSString *) const AIQLaunchableDidProgressNotification;
EXTERN_API(NSString *) const AIQDidDownloadLaunchableNotification;
EXTERN_API(NSString *) const AIQLaunchableDidFailNotification;

EXTERN_API(NSString *) const AIQLaunchableIconDidChangeNotification;

EXTERN_API(NSString *) const kAIQLaunchableSolution;
EXTERN_API(NSString *) const kAIQLaunchableName;
EXTERN_API(NSString *) const kAIQLaunchablePath;
EXTERN_API(NSString *) const kAIQLaunchableIconPath;
EXTERN_API(NSString *) const kAIQLaunchableAvailable;
EXTERN_API(NSString *) const kAIQLaunchableNotification;

EXTERN_API(NSString *) const AIQLaunchableNameUserInfoKey;
EXTERN_API(NSString *) const AIQLaunchablePathUserInfoKey;
EXTERN_API(NSString *) const AIQLaunchableIconPathUserInfoKey;

- (BOOL)reload:(NSError **)error;
- (BOOL)processLaunchables:(void (^)(NSDictionary *, NSError **))processor error:(NSError **)error;
- (NSDictionary *)launchableWithId:(NSString *)identifier error:(NSError **)error;

@end
