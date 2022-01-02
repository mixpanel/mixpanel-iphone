//
//  MPLogger.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <os/log.h>


@interface MPLogger : NSObject

@property (nonatomic, assign) BOOL loggingEnabled;

+ (MPLogger *)sharedInstance;

@end

static inline os_log_t mixpanelLog() {
    static os_log_t logger = nil;
    if (!logger) {
        logger = os_log_create("com.mixpanel.sdk.objc", "Mixpanel");
    }
    return logger;
}

static inline __attribute__((always_inline)) void MPLogDebug(NSString *format, ...) {
    if (![MPLogger sharedInstance].loggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    os_log_with_type(mixpanelLog(), OS_LOG_TYPE_DEBUG, "<Debug>: %s", [formattedString UTF8String]);
}

static inline __attribute__((always_inline)) void MPLogInfo(NSString *format, ...) {
    if (![MPLogger sharedInstance].loggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    os_log_with_type(mixpanelLog(), OS_LOG_TYPE_INFO, "<Info>: %s", [formattedString UTF8String]);
}

static inline __attribute__((always_inline)) void MPLogWarning(NSString *format, ...) {
    if (![MPLogger sharedInstance].loggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    os_log_with_type(mixpanelLog(), OS_LOG_TYPE_ERROR, "<Warning>: %s", [formattedString UTF8String]);
}

static inline __attribute__((always_inline)) void MPLogError(NSString *format, ...) {
    if (![MPLogger sharedInstance].loggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    os_log_with_type(mixpanelLog(), OS_LOG_TYPE_ERROR, "<Error>: %s", [formattedString UTF8String]);
}
