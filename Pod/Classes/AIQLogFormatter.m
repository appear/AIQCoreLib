#import "AIQLogFormatter.h"

@interface AIQLogFormatter ()

- (id)initWithBlacklist:(NSArray *)blacklist;

@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@end

@implementation AIQLogFormatter

+ (AIQLogFormatter *)formatter {
    return [AIQLogFormatter new];
}

+ (AIQLogFormatter *)formatterWithBlacklist:(NSArray *)blacklist {
    return [[AIQLogFormatter alloc] initWithBlacklist:blacklist];
}

- (id)init {
    return [self initWithBlacklist:nil];
}

- (id)initWithBlacklist:(NSArray *)blacklist {
    self = [super init];
    if (self) {
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

        if (blacklist) {
            for (id object in blacklist) {
                if ([object isKindOfClass:[NSNumber class]]) {
                    [self addToBlacklist:((NSNumber *)object).intValue];
                }
            }
        }

        _showContext = YES;
        _showMethod = YES;
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    if ([self isOnBlacklist:logMessage->logContext]) {
        return nil;
    }
    
    NSString *logLevel;
    switch (logMessage->logFlag) {
        case LOG_FLAG_ERROR:
            logLevel = @"ERROR";
            break;
        case LOG_FLAG_WARN:
            logLevel = @"WARN";
            break;
        case LOG_FLAG_DEBUG:
            logLevel = @"DEBUG";
            break;
        default:
            logLevel = @"INFO";
    }

    NSString *dateAndTime = [_dateFormatter stringFromDate:(logMessage->timestamp)];
    NSString *method = (_showMethod) ? [NSString stringWithFormat:@" %@.%@", logMessage.fileName, logMessage.methodName] : @"";
    NSString *context;
    if (_showContext) {
        switch (logMessage->logContext) {
            case 1:
                context = @" CORE";
                break;
            case 2:
                context = @" BRIDGE";
                break;
            case 3:
                context = @" APP";
                break;
            case 4:
                context = @" UI";
                break;
            default:
                context = @" OTHER";
        }
    } else {
        context = @"";
    }
    
    return [NSString stringWithFormat:@"%@ %@%@%@ %@", dateAndTime, logLevel, context, method, logMessage->logMsg];
}

@end
