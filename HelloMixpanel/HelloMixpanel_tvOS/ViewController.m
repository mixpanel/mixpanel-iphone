//
//  ViewController.m
//  tvOS_Example
//
//  Created by Yarden Eitan on 5/31/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "ViewController.h"

@implementation ViewController

- (IBAction)trackEvent:(id)sender {
    [[Mixpanel sharedInstance] track:@"Player Create"
                          properties:@{ @"gender": @"Male", @"weapon": @"Pistol" }];
}

- (IBAction)setPeopleProperties:(id)sender {
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people set:@{ @"gender": @"Male", @"weapon": @"Pistol" }];
    
    // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
    // we're using the automatically generated distinct ID from event tracking.
    [mixpanel identify:mixpanel.distinctId];
    // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
    
    // Note that the call to Mixpanel People identify: can come after properties have been set. Data is queued
    // until identify: is called. Thus, you can set properties before a user is logged in and identify
    // them once you know their user ID.
}

- (IBAction)start:(id)sender {
    [[Mixpanel sharedInstance] timeEvent:@"Timed Event"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[Mixpanel sharedInstance] track:@"Timed Event"];
    });
}

@end
