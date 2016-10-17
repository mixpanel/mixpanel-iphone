//
//  InterfaceController.m
//  HelloMixpanelWatch Extension
//
//  Created by Peter Chien on 10/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

@import Mixpanel;

#import "InterfaceController.h"


@interface InterfaceController()

@property (unsafe_unretained, nonatomic) IBOutlet WKInterfaceButton *timeSomethingButton;
@property (assign, nonatomic) BOOL currentlyTiming;

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (IBAction)tappedTrackButton {
    [[Mixpanel sharedInstance] track:@"tapped button" properties:@{@"tracking" : @[@1, @2]}];
}

static NSString *const timeEventName = @"time something";
- (IBAction)tappedTimeButton {
    if (!self.currentlyTiming) {
        [[Mixpanel sharedInstance] timeEvent:timeEventName];
        [self.timeSomethingButton setTitle:@"Finish Timing"];
    } else {
        [[Mixpanel sharedInstance] track:timeEventName];
        [self.timeSomethingButton setTitle:@"Time Something"];
    }

    self.currentlyTiming = !self.currentlyTiming;
}

- (IBAction)tappedIdentifyButton {
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people set:@{@"watch": [[WKInterfaceDevice currentDevice] name]}];
    [mixpanel identify:mixpanel.distinctId];
}

@end



