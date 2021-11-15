//
//  ViewController.m
//  MixpanelMacDemo
//
//  Copyright © Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "ViewController.h"

@interface ViewController()

@property (unsafe_unretained, nonatomic) IBOutlet NSButton *timeSomethingButton;
@property (assign, nonatomic) BOOL currentlyTiming;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}
- (IBAction)tappedTrackButton:(id)sender {
    [[Mixpanel sharedInstance] track:@"tapped button" properties:@{@"tracking" : @[@1, @2]}];
}


static NSString *const timeEventName = @"time something";

- (IBAction)tappedTimeButton:(id)sender {
    if (!self.currentlyTiming) {
        [[Mixpanel sharedInstance] timeEvent:timeEventName];
        [self.timeSomethingButton setTitle:@"Finish Timing"];
    } else {
        [[Mixpanel sharedInstance] track:timeEventName];
        [self.timeSomethingButton setTitle:@"Time Something"];
    }

    self.currentlyTiming = !self.currentlyTiming;
}

- (IBAction)tappedIdentifyButton:(id)sender {
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people set:@{@"quantity": @10}];
    [mixpanel identify:mixpanel.distinctId];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
