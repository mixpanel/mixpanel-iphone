//
//  MPLogger.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/11/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#ifndef MPLogger_h
#define MPLogger_h

static inline void MPLog(NSString *format, ...) {
    __block va_list arg_list;
    va_start (arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    va_end(arg_list);
    NSLog(@"[Mixpanel] %@", formattedString);
}

#ifdef MIXPANEL_ERROR
#define MixpanelError(...) MPLog(__VA_ARGS__)
#else
#define MixpanelError(...)
#endif

#ifdef MIXPANEL_DEBUG
#define MixpanelDebug(...) MPLog(__VA_ARGS__)
#else
#define MixpanelDebug(...)
#endif

#ifdef MIXPANEL_MESSAGING_DEBUG
#define MessagingDebug(...) MPLog(__VA_ARGS__)
#else
#define MessagingDebug(...)
#endif

#endif
