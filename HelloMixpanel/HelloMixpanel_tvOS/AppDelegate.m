//
//  AppDelegate.m
//  tvOS_Example
//
//  Created by Yarden Eitan on 5/31/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "AppDelegate.h"

// IMPORTANT!!! replace with your api token from https://mixpanel.com/account/
#define MIXPANEL_TOKEN @"YOUR_MIXPANEL_PROJECT_TOKEN"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN launchOptions:nil];
    self.mixpanel.flushInterval = 20; // defaults to 60 seconds
    
    // Set some super properties, which will be added to every tracked event
    [self.mixpanel registerSuperProperties:@{@"Plan": @"Premium"}];
    
    // Start timing the session, then we'll have a duration when the user leaves the app
    [self.mixpanel timeEvent:@"Session"];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self.mixpanel track:@"Session"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    self.bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"%@ background task %lu cut short", self, (unsigned long)self.bgTask);
        
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSLog(@"%@ starting background task %lu", self, (unsigned long)self.bgTask);
        
        // track some events and set some people properties
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel registerSuperProperties:@{@"Background Super Property": @"Hi!"}];
        [mixpanel track:@"Background Event"];
        [mixpanel.people set:@"Entered Background" to:[NSDate date]];
        
        NSLog(@"%@ ending background task %lu", self, (unsigned long)self.bgTask);
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    });
    
    NSLog(@"%@ dispatched background task %lu", self, (unsigned long)self.bgTask);
}

@end
