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
    // Override point for customization after application launch.
    
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN launchOptions:nil];
    self.mixpanel.flushInterval = 20; // defaults to 60 seconds
    
    // Set some super properties, which will be added to every tracked event
    [self.mixpanel registerSuperProperties:@{@"Plan": @"Premium"}];
    
    // Name a user in Mixpanel Streams
    self.mixpanel.nameTag = @"Walter Sobchak";
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    NSNumber *seconds = @([[NSDate date] timeIntervalSinceDate:self.startTime]);
    [[Mixpanel sharedInstance] track:@"Session" properties:@{@"Length": seconds}];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
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
        [mixpanel.people set:@"Background Property" to:[NSDate date]];
        
        NSLog(@"%@ ending background task %lu", self, (unsigned long)self.bgTask);
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    });
    
    NSLog(@"%@ dispatched background task %lu", self, (unsigned long)self.bgTask);

}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    self.startTime = [NSDate date];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
