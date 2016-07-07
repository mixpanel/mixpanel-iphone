#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#ifndef NSFoundationVersionNumber_iOS_9_0
// support for Xcode 7.*
#define NSFoundationVersionNumber_iOS_8_x_Max 1199
#define NSFoundationVersionNumber_iOS_9_0 1240.1
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif
#endif
