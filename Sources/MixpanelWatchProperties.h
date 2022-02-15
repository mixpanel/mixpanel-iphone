//
//  MixpanelWatchProperties.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#if TARGET_OS_WATCH

#import <Foundation/Foundation.h>

@interface MixpanelWatchProperties : NSObject

+ (NSDictionary *)collectDeviceProperties;
+ (NSString *)systemVersion;

@end

#endif
