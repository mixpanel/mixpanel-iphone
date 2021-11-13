//
//  AppDelegate.m
//  MixpanelMacDemo
//
//  Copyright © Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "AppDelegate.h"

#define MIXPANEL_TOKEN @"YOUR_MIXPANEL_PROJECT_TOKEN"

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
    self.mixpanel.enableLogging = YES;
    [self.mixpanel registerSuperProperties:@{@"super mac": @1}];
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
