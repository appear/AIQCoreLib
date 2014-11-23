#import "AIQLog.h"

int aiqLogLevel = LOG_LEVEL_OFF;

@implementation AIQLog

+ (void)load {
    aiqLogLevel = LOG_LEVEL_OFF;
}

+ (int)ddLogLevel {
    return aiqLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    aiqLogLevel = logLevel;
}

@end