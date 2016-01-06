#import <CoreLocation/CoreLocation.h>

#import "AIQLocation.h"
#import "AIQLog.h"
#import "common.h"

NSString *const AIQLocationUpdatedEvent = @"AIQLocationUpdated";
NSString *const AIQLocationFailedEvent = @"AIQLocationFailed";

NSString *const AIQNewLocationKey = @"AIQNewLocation";
NSString *const AIQOldLocationKey = @"AIQOldLocation";

@interface AIQLocation () <CLLocationManagerDelegate>

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, assign) NSUInteger monitoringSignificantLocationChanges;
@property (nonatomic, retain) CLLocation *currentLocation;

@end

@implementation AIQLocation

+ (id)instance {
    static AIQLocation *instance = nil;
    @synchronized(self) {
        if (! instance) {
            instance = [[AIQLocation alloc] init];
        }
    }
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return self;
}

- (void)startMonitoringSignificantLocationChanges {
    if (_monitoringSignificantLocationChanges == 0) {
        AIQLogCInfo(1, @"Starting location monitoring");
        
        if ([_locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [_locationManager requestAlwaysAuthorization];
        } else {
            [_locationManager startMonitoringSignificantLocationChanges];
        }
    }
    
    if (_currentLocation) {
        AIQLogCInfo(1, @"Location monitoring already running, forcing reload");
        NOTIFY(AIQLocationUpdatedEvent, self, (@{AIQNewLocationKey: _currentLocation, AIQOldLocationKey: _currentLocation}));
    } else {
        AIQLogCInfo(1, @"No location to propagate");
    }
    
    _monitoringSignificantLocationChanges++;
}

- (void)stopMonitoringSignificantLocationChanges {
    _monitoringSignificantLocationChanges--;
    if (_monitoringSignificantLocationChanges == 0) {
        AIQLogCInfo(1, @"Stopping location monitoring");
        [_locationManager stopMonitoringSignificantLocationChanges];
    } else {
        AIQLogCInfo(1, @"Ignoring stop request, %d active listeners", (int)_monitoringSignificantLocationChanges);
    }
}

- (void)pause {
    AIQLogCInfo(1, @"Pausing location monitoring");
    [_locationManager stopMonitoringSignificantLocationChanges];
}

- (void)resume {
    if (_monitoringSignificantLocationChanges != 0) {
        AIQLogCInfo(1, @"Resuming location monitoring");
        [_locationManager startMonitoringSignificantLocationChanges];
        
        // force reload
        if (_currentLocation) {
            NOTIFY(AIQLocationUpdatedEvent, self, (@{AIQNewLocationKey: _currentLocation, AIQOldLocationKey: _currentLocation}));
        } else {
            AIQLogCInfo(1, @"No location to propagate");
        }
    } else {
        AIQLogCInfo(1, @"Not resuming, no active listeners");
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways) {
        [manager startMonitoringSignificantLocationChanges];
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    AIQLogCInfo(1, @"Location changed to %@", locations.lastObject);
    NOTIFY(AIQLocationUpdatedEvent, self, @{AIQNewLocationKey: locations.lastObject});
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    AIQLogCWarn(1, @"Location failed: %@", error.localizedDescription);
    NOTIFY(AIQLocationFailedEvent, self, nil);
}

@end
