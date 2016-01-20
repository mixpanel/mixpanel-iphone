#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#ifndef NSFoundationVersionNumber_iOS_8_0
// support for Xcode 6.*
#define NSFoundationVersionNumber_iOS_8_0 1140.11
#ifndef NSFoundationVersionNumber_iOS_7_0
// support for Xcode 5.1.1
#define NSFoundationVersionNumber_iOS_7_0 1047.20
#endif
#endif
#endif
