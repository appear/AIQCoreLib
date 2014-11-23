#import <Foundation/Foundation.h>

#import "DDLog.h"

extern int aiqLogLevel;

#define AIQ_LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, fnct, frmt, ...) \
    [AIQLog log:isAsynchronous                                              \
          level:lvl                                                         \
           flag:flg                                                         \
        context:ctx                                                         \
           file:__FILE__                                                    \
       function:fnct                                                        \
           line:__LINE__                                                    \
            tag:atag                                                        \
         format:(frmt), ##__VA_ARGS__]

#define AIQ_LOG_OBJC_MAYBE(async, lvl, flg, ctx, frmt, ...) AIQ_LOG_MAYBE(async, lvl, flg, ctx, sel_getName(_cmd), frmt, ##__VA_ARGS__)
#define AIQ_LOG_MAYBE(async, lvl, flg, ctx, fnct, frmt, ...) do { if(lvl & flg) AIQ_LOG_MACRO(async, lvl, flg, ctx, nil, fnct, frmt, ##__VA_ARGS__); } while(0)
#define AIQ_ASYNC_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) AIQ_LOG_OBJC_MAYBE(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define AIQLogError(frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_ERROR, 0, frmt, ##__VA_ARGS__)
#define AIQLogWarn(frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_WARN, 0, frmt, ##__VA_ARGS__)
#define AIQLogInfo(frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_INFO, 0, frmt, ##__VA_ARGS__)
#define AIQLogDebug(frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_DEBUG, 0, frmt, ##__VA_ARGS__)
#define AIQLogVerbose(frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)

#define AIQLogCError(ctx, frmt, ...) AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_ERROR, ctx, frmt, ##__VA_ARGS__)
#define AIQLogCWarn(ctx, frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_WARN, ctx, frmt, ##__VA_ARGS__)
#define AIQLogCInfo(ctx, frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_INFO, ctx, frmt, ##__VA_ARGS__)
#define AIQLogCDebug(ctx, frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_DEBUG, ctx, frmt, ##__VA_ARGS__)
#define AIQLogCVerbose(ctx, frmt, ...)   AIQ_ASYNC_LOG_OBJC_MAYBE(aiqLogLevel, LOG_FLAG_VERBOSE, ctx, frmt, ##__VA_ARGS__)

@interface AIQLog : DDLog<DDRegisteredDynamicLogging>

@end