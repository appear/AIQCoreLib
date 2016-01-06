#import "AIQLog.h"
#import "AIQLogFormatter.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"

int aiqLogLevel = LOG_LEVEL_OFF;

@implementation AIQLog

+ (void)load {
    aiqLogLevel = LOG_LEVEL_OFF;

    AIQLogFormatter *formatter = [AIQLogFormatter new];
    [[DDASLLogger sharedInstance] setLogFormatter:formatter];
    [[DDTTYLogger sharedInstance] setLogFormatter:formatter];
}

+ (int)ddLogLevel {
    return aiqLogLevel;
}

+ (void)ddSetLogLevel:(int)logLevel {
    aiqLogLevel = logLevel;
}

@end
