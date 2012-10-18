//
// AppDelegate.m
// HelloMixpanel
//
// Copyright 2012 Mixpanel
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Mixpanel.h"

#import "AppDelegate.h"

#import "ViewController.h"

// IMPORTANT!!! replace with you api token from https://mixpanel.com/account/
#define MIXPANEL_TOKEN @"YOUR MIXPANEL PROJECT TOKEN"

@implementation AppDelegate

- (void)dealloc
{
    [_startTime release];
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    // Override point for customization after application launch.
    
    // Initialize the MixpanelAPI object
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
    
    // Set the upload interval to 10 seconds for demonstration purposes. This would be overkill for most applications.
    self.mixpanel.flushInterval = 10; // defaults to 60 seconds
    
    // Name a user in Mixpanel Streams
    self.mixpanel.nameTag = @"Walter Sobchak";
    
    // Set some super properties, which will be added to every tracked event
    [self.mixpanel registerSuperProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"Premium", @"Plan", nil]];
    
    self.viewController = [[[ViewController alloc] initWithNibName:@"ViewController" bundle:nil] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    
    return YES;
}

#pragma mark * Push notifications

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    [self.mixpanel.people addPushDeviceToken:devToken];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error in registration. Error: %@", err);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    // Show alert for push notifications recevied while the app is running
    NSString *message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

#pragma mark * Session timing example

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    self.startTime = [NSDate date];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSNumber *seconds = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:self.startTime]];
    [[Mixpanel sharedInstance] track:@"Session" properties:[NSDictionary dictionaryWithObject:seconds forKey:@"Length"]];
}

@end
