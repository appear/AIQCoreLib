#import <Foundation/Foundation.h>
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDContextFilterLogFormatter.h>

@interface AIQLogFormatter : DDContextBlacklistFilterLogFormatter

@property (nonatomic, assign) BOOL showContext;
@property (nonatomic, assign) BOOL showMethod;

+ (AIQLogFormatter *)formatter;
+ (AIQLogFormatter *)formatterWithBlacklist:(NSArray *)blacklist;

@end
