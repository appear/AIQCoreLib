#import <CoreLocation/CoreLocation.h>

#import "AIQLocation.h"
#import "AIQLocationContextProvider.h"
#import "AIQLog.h"
#import "common.h"

@implementation AIQLocationContextProvider

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return ![key isEqualToString:@"data"];
}

- (id)init {
    self = [super init];
    if (self) {
        self.data = [NSMutableDictionary dictionary];
        
        LISTEN(self, @selector(locationChanged:), AIQLocationUpdatedEvent);
        [[AIQLocation instance] startMonitoringSignificantLocationChanges];
    }
    return self;
}

- (void)dealloc {
    [[AIQLocation instance] stopMonitoringSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)getName {
    return @"com.appearnetworks.aiq.location";
}

#pragma mark - Private API

- (void)locationChanged:(NSNotification *)notification {
    [self willChangeValueForKey:@"data"];
    CLLocation *location = notification.userInfo[AIQNewLocationKey];
    
    AIQLogCInfo(1, @"Location changed to (%f, %f)", location.coordinate.latitude, location.coordinate.longitude);
    if (location) {
        ((NSMutableDictionary *)_data)[@"latitude"] = @(location.coordinate.latitude);
        ((NSMutableDictionary *)_data)[@"longitude"] = @(location.coordinate.longitude);
    } else {
        [(NSMutableDictionary *)_data removeObjectForKey:@"latitude"];
        [(NSMutableDictionary *)_data removeObjectForKey:@"longitude"];
    }
    [self didChangeValueForKey:@"data"];
}

@end
