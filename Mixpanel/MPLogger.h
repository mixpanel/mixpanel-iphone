//
//  MPLogger.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/11/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <asl.h>

static bool gLoggingEnabled = NO;
static inline void MPSetLoggingEnabled(BOOL enabled) {

}

#define __MP_MAKE_LOG_FUNCTION(LEVEL, NAME) \
static inline void NAME(NSString *format, ...) { \
    if (!gLoggingEnabled) return; \
    va_list arg_list; \
    va_start(arg_list, format); \
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list]; \
    asl_log(NULL, NULL, (LEVEL), "%s", [formattedString UTF8String]); \
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