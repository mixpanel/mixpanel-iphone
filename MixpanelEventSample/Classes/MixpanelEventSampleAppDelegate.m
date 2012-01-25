//
//  MixpanelEventSampleAppDelegate.m
//  MixpanelEventSample
//
//

#import "MixpanelEventSampleAppDelegate.h"
#import "MixpanelEventSampleViewController.h"
#import "MixpanelAPI.h"
#define MIXPANEL_TOKEN @"1094957c9f6d50ab07a69b7daab06ff0"
@implementation MixpanelEventSampleAppDelegate

@synthesize window;
@synthesize viewController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
    //Initialize the MixpanelAPI object
    mixpanel = [MixpanelAPI sharedAPIWithToken:MIXPANEL_TOKEN];
    // Add the view controller's view to the window and display.
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
    return YES;
}



@end
