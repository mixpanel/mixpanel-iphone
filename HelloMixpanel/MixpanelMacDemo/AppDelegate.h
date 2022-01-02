//
//  AppDelegate.h
//  MixpanelMacDemo
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Mixpanel;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) Mixpanel *mixpanel;

@end

