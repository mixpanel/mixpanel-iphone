//
//  MixpanelWatchProperties.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#if defined(MIXPANEL_WATCHOS)

#import <Foundation/Foundation.h>

@interface MixpanelWatchProperties : NSObject

+ (NSDictionary *)collectDeviceProperties;
+ (NSString *)systemVersion;

@end

#endif
