//
//  MPLogger.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/11/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <asl.h>
#import <pthread.h>
#import <os/log.h>

static BOOL gLoggingEnabled = NO;
static NSObject *loggingLockObject;

#define __MP_MAKE_LOG_FUNCTION(LEVEL, NAME) \
static inline void NAME(NSString *format, ...) { \
    @synchronized(loggingLockObject) { \
        if (!gLoggingEnabled) return; \
        va_list arg_list; \
        va_start(arg_list, format); \
        NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list]; \
        asl_add_log_file(NULL, STDERR_FILENO); \
        asl_log(NULL, NULL, (LEVEL), "%s", [formattedString UTF8String]); \
        va_end(arg_list); \
    } \
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// Something has failed.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_ERR, MPLogError_legacy)

// Something is amiss and might fail if not corrected.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_WARNING, MPLogWarning_legacy)

// The lowest priority that you would normally log, and purely informational in nature.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_INFO, MPLogInfo_legacy)

// The lowest priority, and normally not logged except for code based messages.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_DEBUG, MPLogDebug_legacy)

#undef __MP_MAKE_LOG_FUNCTION
#pragma clang diagnostic pop

static inline os_log_t mixpanelLog() {
    static os_log_t logger = nil;
    if (!logger) {
        if (@available(iOS 10.0, macOS 10.12, *)) {
            logger = os_log_create("com.mixpanel.sdk.objc", "Mixpanel");
        }
    }
    return logger;
}

static inline void MPLogDebug(NSString *format, ...) {
    if (!gLoggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    if (@available(iOS 10.0, macOS 10.12, *)) {
        os_log_with_type(mixpanelLog(), OS_LOG_TYPE_DEBUG, "<Debug>: %s", [formattedString UTF8String]);
    }
    else {
        MPLogDebug_legacy(@"%s", [formattedString UTF8String]);
    }
}

static inline void MPLogInfo(NSString *format, ...) {
    if (!gLoggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    if (@available(iOS 10.0, macOS 10.12, *)) {
        os_log_with_type(mixpanelLog(), OS_LOG_TYPE_INFO, "<Info>: %s", [formattedString UTF8String]);
    }
    else {
        MPLogInfo_legacy(@"%s", [formattedString UTF8String]);
    }
}

static inline void MPLogWarning(NSString *format, ...) {
    if (!gLoggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    if (@available(iOS 10.0, macOS 10.12, *)) {
        os_log_with_type(mixpanelLog(), OS_LOG_TYPE_ERROR, "<Warning>: %s", [formattedString UTF8String]);
    }
    else {
        MPLogWarning_legacy(@"%s", [formattedString UTF8String]);
    }
}

static inline void MPLogError(NSString *format, ...) {
    if (!gLoggingEnabled) return;
    va_list arg_list;
    va_start(arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    if (@available(iOS 10.0, macOS 10.12, *)) {
        os_log_with_type(mixpanelLog(), OS_LOG_TYPE_ERROR, "<Error>: %s", [formattedString UTF8String]);
    }
    else {
        MPLogError_legacy(@"%s", [formattedString UTF8String]);
    }
}
