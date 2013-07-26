//
//  MXPAppDelegate.m
//  HelloMixpanelDesktop
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


#import "MXPAppDelegate.h"
#import "Mixpanel.h"
#import "MXPMainWindowController.h"

// IMPORTANT!!! replace with you api token from https://mixpanel.com/account/
#define MIXPANEL_TOKEN @"YOUR MIXPANEL PROJECT TOKEN"


@implementation MXPAppDelegate

#pragma mark * Life cycle

- (void)dealloc
{
    [_startTime release];
    [_mainWindowController release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.mainWindowController = [[MXPMainWindowController alloc] initWithWindowNibName:nil];
    [self.mainWindowController showWindow:nil];

    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
    
    // Set the upload interval to 20 seconds for demonstration purposes. This would be overkill for most applications.
    self.mixpanel.flushInterval = 20; // defaults to 60 seconds
    
    // Name a user in Mixpanel Streams
    self.mixpanel.nameTag = @"Walter Sobchak";
    
    // Set some super properties, which will be added to every tracked event
    [self.mixpanel registerSuperProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"Premium", @"Plan", nil]];
    
    [NSApp registerForRemoteNotificationTypes:(NSRemoteNotificationTypeBadge | NSRemoteNotificationTypeSound | NSRemoteNotificationTypeAlert)];
}

#pragma mark * Push notifications

- (void)application:(NSApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [self.mixpanel.people addPushDeviceToken:deviceToken];
}

- (void)application:(NSApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
     NSLog(@"%@ push registration error: %@", self, error);
}

- (void)application:(NSApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSString *message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
}


@end
