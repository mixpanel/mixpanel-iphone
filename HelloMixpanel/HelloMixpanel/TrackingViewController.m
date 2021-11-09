//
//  TrackingViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/4/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//
#import "TrackingViewController.h"

@interface TrackingViewController ()

@end

@implementation TrackingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.trackActions = @{@"1.  Track Event": ^(void){[self testTrackEvent];},
                          @"2.  Track Event with Properties": ^(void){[self testTrackEventWithProperties];},
                          @"3.  Time Event 2secs": ^(void){[self testTimedEvent];},
                          @"4.  Clear Timed Events": ^(void){[self testClearTimedEvent];},
                          @"5.  Get Current SuperProperties": ^(void){[self testGetCurrentSuperProperties];},
                          @"6.  Clear SuperProperties": ^(void){[self testClearSuperProperties];},
                          @"7.  Register SuperProperties": ^(void){[self testRegisterSuperProperties];},
                          @"8.  Register SuperProperties Once": ^(void){[self testRegisterSuperPropertiesOnce];},
                          @"9.  Register SP Once w Default Value": ^(void){[self testRegisterSuperPropertiesOnceWithDefaultValue];},
                          @"10. Unregister SuperProperty": ^(void){[self testUnRegisterSuperProperty];}
                          };
    self.trackActionsArray = [self.trackActions.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self.tableView reloadData];
}


#pragma mark - track actions
- (void)testTrackEvent
{
    NSString *eventTitle = @"Track Event";
    [self.mixpanel track:eventTitle];
    [self presentLogMessage:[NSString stringWithFormat:@"Event: %@", eventTitle] title:eventTitle];
}

- (void)testTrackEventWithProperties
{
    NSString *eventTitle = @"Track Event With Properties!";
    NSDictionary *properties = @{@"Cool Property": @"Property Value"};
    [self.mixpanel track:eventTitle properties:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Event: %@\n Properties: %@", eventTitle, properties] title:eventTitle];
}

- (void)testTimedEvent
{
    NSString *eventTitle = @"Timed Event";
    [self.mixpanel timeEvent:eventTitle];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.mixpanel track:eventTitle];
        [self presentLogMessage:[NSString stringWithFormat:@"Timed Event: %@\n", eventTitle] title:eventTitle];
    });
}

- (void)testClearTimedEvent
{
    NSString *eventTitle = @"Clear Timed Event";
    [self.mixpanel timeEvent:eventTitle];
    [self.mixpanel clearTimedEvents];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.mixpanel track:eventTitle];
        [self presentLogMessage:@"Timed Events Cleared" title:eventTitle];
    });
}

- (void)testGetCurrentSuperProperties
{
    [self presentLogMessage:[NSString stringWithFormat:@"Super Properties: %@", self.mixpanel.currentSuperProperties] title:@"Get Super Properties"];
}

- (void)testClearSuperProperties
{
    [self.mixpanel clearSuperProperties];
    [self presentLogMessage:@"Cleared Super Properties" title:@"Clear Super Properties"];
}

- (void)testRegisterSuperProperties
{
    NSDictionary *properties = @{@"Super Property 1": @1,
                                 @"Super Property 2": @"p2",
                                 @"Super Property 3": [NSDate date],
                                 @"Super Property 4": @{@"a": @"b"},
                                 @"Super Property 5": @[@3, @"a", [NSDate date]],
                                 @"Super Property 6":
                                     [NSURL URLWithString:@"https://mixpanel.com"],
                                 @"Super Property 7": [NSNull null]};
    [self.mixpanel registerSuperProperties:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Register Super Properties"];
}

- (void)testRegisterSuperPropertiesOnce
{
    NSDictionary *properties = @{@"Super Property 1": @2.3};
    [self.mixpanel registerSuperPropertiesOnce:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Register Super Properties Once"];
}

- (void)testRegisterSuperPropertiesOnceWithDefaultValue
{
    NSDictionary *properties = @{@"Super Property 1": @1.2};
    [self.mixpanel registerSuperPropertiesOnce:properties defaultValue:@2.3];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties %@ with Default Value: 2.3", properties] title:@"Register Super Properties Once"];
}

- (void)testUnRegisterSuperProperty
{
    [self.mixpanel unregisterSuperProperty:@"Super Property 1"];
    [self presentLogMessage:[NSString stringWithFormat:@"Unregister Super Properties %@", @"Super Property 1"] title:@"Unregister Super Properties"];
}

@end
