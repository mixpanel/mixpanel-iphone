//
//  AppDelegate.h
//  MixpanelMacDemo
//
//  Created by ZIHE JIA on 11/8/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Mixpanel;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) Mixpanel *mixpanel;

@end

