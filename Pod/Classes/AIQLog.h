/*
 The MIT License (MIT)

 Copyright (c) 2015 Appear Networks AB

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

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