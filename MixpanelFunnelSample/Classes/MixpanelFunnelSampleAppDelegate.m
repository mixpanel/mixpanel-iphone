//
//  MixpanelFunnelSampleAppDelegate.m
//  MixpanelFunnelSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright elfredpagan.com 2010. All rights reserved.
//

#import "MixpanelFunnelSampleAppDelegate.h"
#import "MixpanelFunnelSampleViewController.h"
#import "MixpanelAPI.h"
#define MIXPANEL_TOKEN @"YOUR_TOKEN_HERE"
@implementation MixpanelFunnelSampleAppDelegate

@synthesize window;
@synthesize viewController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    // Override point for customization after application launch.
	mixpanel = [MixpanelAPI sharedAPIWithToken:MIXPANEL_TOKEN];
    // Add the view controller's view to the window and display.
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
    return YES;
}
- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end
