//
//  AppDelegate.m
//  HelloMixpanel_macOS
//
//  Created by Peter Gulyas on 2016-11-29.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "AppDelegate.h"

#define MIX_PANEL_KEY @"ENTER_YOUR_KEY_HERE"
@import Mixpanel;
@interface AppDelegate ()
    @property (nonatomic, strong) Mixpanel* mixpanel;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIX_PANEL_KEY];
    if (self.mixpanel == nil){
        self.mixpanel = [[Mixpanel alloc] initWithToken:MIX_PANEL_KEY andFlushInterval:60];
    }
    self.mixpanel.enableLogging = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.mixpanel track:@"mac-test" properties:nil];
    });
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
