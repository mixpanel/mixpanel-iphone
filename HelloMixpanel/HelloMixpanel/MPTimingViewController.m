//
//  MPTimingViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 9/12/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

@import Mixpanel;
#import "MPTimingViewController.h"

@interface MPTimingViewController ()

@property (nonatomic) IBOutlet UILabel *timerLabel;
@property (nonatomic) IBOutlet UILabel *splitLabel;

@property (nonatomic) NSTimeInterval timeStart;
@property (nonatomic) NSTimeInterval split;
@property (nonatomic) NSTimer *timer;


@end

@implementation MPTimingViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.timeStart = 0;
}

- (IBAction)start:(id)sender
{
    self.timeStart = [NSDate timeIntervalSinceReferenceDate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[Mixpanel sharedInstance] timeEvent:@"Timing"];
}

- (IBAction)track:(id)sender
{
    [self.timer invalidate];
    self.split = [NSDate timeIntervalSinceReferenceDate] - self.timeStart;
    self.splitLabel.text = [NSString stringWithFormat:@"%.3f", self.split];
    [[Mixpanel sharedInstance] track:@"Timing"];
}

- (void)tick
{
    self.timerLabel.text = [NSString stringWithFormat:@"%.3f", [NSDate timeIntervalSinceReferenceDate] - self.timeStart];
}

@end
