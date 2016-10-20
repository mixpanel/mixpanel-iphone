//
//  MixpanelWatchProperties.m
//  Mixpanel
//
//  Created by Peter Chien on 10/14/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelWatchProperties.h"
#import <WatchKit/WatchKit.h>

@implementation MixpanelWatchProperties

+ (NSDictionary *)collectDeviceProperties {
    NSMutableDictionary *mutableProperties = [NSMutableDictionary dictionaryWithCapacity:5];

    WKInterfaceDevice *device = [WKInterfaceDevice currentDevice];
    mutableProperties[@"$os"] = [device systemName];
    mutableProperties[@"$os_version"] = [device systemVersion];
    mutableProperties[@"$watch_model"] = [self watchModel];

    CGSize screenSize = device.screenBounds.size;
    mutableProperties[@"$screen_width"] = @(screenSize.width);
    mutableProperties[@"$screen_height"] = @(screenSize.height);

    return [mutableProperties copy];
}

+ (NSString *)watchModel {
    static const CGFloat kAppleWatchScreenWidthSmall = 136.f;
    static const CGFloat kAppleWatchScreenWidthLarge = 152.f;

    CGFloat screenWidth = [WKInterfaceDevice currentDevice].screenBounds.size.width;
    if (screenWidth <= kAppleWatchScreenWidthSmall) {
        return @"Apple Watch 38mm";
    } else if (screenWidth <= kAppleWatchScreenWidthLarge) {
        return @"Apple Watch 42mm";
    }

    return @"Apple Watch";
}

+ (NSString *)systemVersion {
    return [WKInterfaceDevice currentDevice].systemVersion;
}

@end
