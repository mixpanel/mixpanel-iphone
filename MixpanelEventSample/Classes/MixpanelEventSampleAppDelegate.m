//
//  MixpanelEventSampleAppDelegate.m
//  MixpanelEventSample
//
//

#import "MixpanelEventSampleAppDelegate.h"
#import "MixpanelEventSampleViewController.h"
#import "MixpanelAPI.h"
#define MIXPANEL_TOKEN @"886377995387084ca48b4c7a1d6e1aa3"
@implementation MixpanelEventSampleAppDelegate

@synthesize window;
@synthesize viewController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
    //Initialize the MixpanelAPI object
    mixpanel = [MixpanelAPI sharedAPIWithToken:MIXPANEL_TOKEN];
    
    // Set the upload interval to 5 seconds for testings
    // If not set, it defaults to 30 seconds
    [mixpanel setUploadInterval:5];
    //[mixpanel setServerURL:@"http://m.kasrak.com"];

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
