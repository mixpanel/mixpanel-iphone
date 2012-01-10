//
//  AppDelegate.m
//  MixpanelEventSampleCocoa
//
//

#import "AppDelegate.h"
#import "MixpanelAPI.h"

#define MIXPANEL_TOKEN @"YOUR_TOKEN_HERE"

@implementation AppDelegate

@synthesize window = _window;
@synthesize createUserButton;
@synthesize genderMatrix;
@synthesize weaponMatrix;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    mixpanel = [MixpanelAPI sharedAPIWithToken:MIXPANEL_TOKEN];
}

- (IBAction)didClickCreateUser:(id)sender {
    NSString *gender = [[genderMatrix selectedCell] title];
    NSString *weapon = [[weaponMatrix selectedCell] title];

    [mixpanel track:@"Player Create" 
         properties:[NSDictionary dictionaryWithObjectsAndKeys:
                     gender, @"gender",
                     weapon, @"weapon",
                     nil]];
}

@end
