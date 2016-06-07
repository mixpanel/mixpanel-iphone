//
//  ViewController.m
//  tvOS_Example
//
//  Created by Yarden Eitan on 5/31/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)trackEvent:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    NSString *gender = @"Male";
    NSString *weapon = @"Pistol";
    [mixpanel track:@"Player Create" properties:@{@"gender": gender, @"weapon": weapon}];
}

- (IBAction)setPeopleProperties:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    NSString *gender = @"Male";
    NSString *weapon = @"Pistol";
    [mixpanel.people set:@{@"gender": gender, @"weapon": weapon}];
    // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
    // we're using the automatically generated distinct ID from event tracking, based on the device's MAC address.
    // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
    // Note that the call to Mixpanel People identify: can come after properties have been set. We queue them until
    // identify: is called and flush them at that time. That way, you can set properties before a user is logged in
    // and identify them once you know their user ID.
    [mixpanel identify:mixpanel.distinctId];
}

- (IBAction)start:(id)sender
{
    [[Mixpanel sharedInstance] timeEvent:@"Timing"];
    dispatch_queue_t serverDelaySimulationThread = dispatch_queue_create("com.xxx.serverDelay", nil);
    dispatch_async(serverDelaySimulationThread, ^{
        [NSThread sleepForTimeInterval:2.0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[Mixpanel sharedInstance] track:@"Timing"];

        });
    });
}




@end
