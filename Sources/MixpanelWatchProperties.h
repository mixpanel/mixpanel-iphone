//
//  MixpanelWatchProperties.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//
#import <TargetConditionals.h>

#if TARGET_OS_WATCH

#import <Foundation/Foundation.h>

@interface MixpanelWatchProperties : NSObject

+ (NSDictionary *)collectDeviceProperties;
+ (NSString *)systemVersion;

@end

#endif
