//
//  MPLogger.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/11/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifndef AloomaLogger_h
#define AloomaLogger_h

static inline void AloomaLog(NSString *format, ...) {
    __block va_list arg_list;
    va_start (arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    va_end(arg_list);
    NSLog(@"[Alooma] %@", formattedString);
}

#ifdef ALOOMA_ERROR
#define AloomaError(...) AloomaLog(__VA_ARGS__)
#else
#define AloomaError(...)
#endif

#ifdef ALOOMA_DEBUG
#define AloomaDebug(...) AloomaLog(__VA_ARGS__)
#else
#define AloomaDebug(...)
#endif

#ifdef ALOOMA_MESSAGING_DEBUG
#define AloomaMessagingDebug(...) AloomaLog(__VA_ARGS__)
#else
#define AloomaMessagingDebug(...)
#endif

#endif
