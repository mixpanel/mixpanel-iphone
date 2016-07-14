//
//  MPLogger.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/11/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <asl.h>

static inline void MPSetLoggingEnabled(BOOL enabled) {
    if (enabled) {
        asl_add_log_file(NULL, STDERR_FILENO);
        asl_set_filter(NULL, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
    } else {
        asl_remove_log_file(NULL, STDERR_FILENO);
    }
}

#define __MP_MAKE_LOG_FUNCTION(LEVEL, NAME) \
static inline void NAME(NSString *format, ...) { \
    va_list arg_list; \
    va_start(arg_list, format); \
    aslmsg msg = asl_new(ASL_TYPE_MSG); \
    asl_set(msg, ASL_KEY_READ_UID, "-1");\
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list]; \
    asl_log(NULL, msg, (LEVEL), "[Mixpanel] %s", [formattedString UTF8String]); \
    asl_free(msg); \
    va_end(arg_list); \
}

// Something has failed.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_ERR, MPLogError)

// Something is amiss and might fail if not corrected.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_WARNING, MPLogWarning)

// The lowest priority that you would normally log, and purely informational in nature.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_INFO, MPLogInfo)

// The lowest priority, and normally not logged except for code based messages.
__MP_MAKE_LOG_FUNCTION(ASL_LEVEL_DEBUG, MPLogDebug)

#undef __MP_MAKE_LOG_FUNCTION