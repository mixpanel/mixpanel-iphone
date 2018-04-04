//
//  TrackingViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/4/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//
@import Mixpanel;
#import "TrackingViewController.h"

typedef void (^ActionBlock)(void);


@interface TrackingViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSDictionary *trackActions;
@property (nonatomic, strong) Mixpanel *mixpanel;

@end

@implementation TrackingViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    self.trackActions = @{@"Track Event": ^(void){[self testTrackEvent];},
                          @"Track Event with Properties": ^(void){[self testTrackEventWithProperties];},
                          @"Time Event 2secs": ^(void){[self testTimedEvent];},
                          @"Clear Timed Events": ^(void){[self testClearTimedEvent];},
                          @"Get Current SuperProperties": ^(void){[self testGetCurrentSuperProperties];},
                          @"Clear SuperProperties": ^(void){[self testClearSuperProperties];},
                          @"Register SuperProperties": ^(void){[self testRegisterSuperProperties];},
                          @"Register SuperProperties Once": ^(void){[self testRegisterSuperPropertiesOnce];},
                          @"Register SP Once w Default Value": ^(void){[self testRegisterSuperPropertiesOnceWithDefaultValue];},
                          @"Unregister SuperProperty": ^(void){[self testUnRegisterSuperProperty];}
                          };
    self.mixpanel = [Mixpanel sharedInstance];
}

#pragma mark - tableView delegate and datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.trackActions.allKeys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"trackingCellIdentifier"];
    cell.textLabel.text = self.trackActions.allKeys[(NSUInteger)indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ActionBlock actionBlock = self.trackActions[self.trackActions.allKeys[(NSUInteger)indexPath.row]];
    actionBlock();
    if (indexPath) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - track actions
- (void)presentLogMessage:(NSString *)message title:(NSString *)title
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:title
                                 message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:@"OK"
                               style:UIAlertActionStyleDefault
                               handler:nil];
    [alert addAction:okButton];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)testTrackActions
{
    NSLog(@"my block");
}

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
    NSString *eventTitle = @"Get Super Properties";
    [self presentLogMessage:[NSString stringWithFormat:@"Super Properties: %@", self.mixpanel.currentSuperProperties] title:eventTitle];
}

- (void)testClearSuperProperties
{
    NSString *eventTitle = @"Clear Super Properties";
    [self.mixpanel clearSuperProperties];
    [self presentLogMessage:@"Cleared Super Properties" title:eventTitle];
}

- (void)testRegisterSuperProperties
{
    NSString *eventTitle = @"Register Super Properties";
    NSDictionary *properties = @{@"Super Property 1": @1,
                                 @"Super Property 2": @"p2",
                                 @"Super Property 3": [NSDate date],
                                 @"Super Property 4": @{@"a": @"b"},
                                 @"Super Property 5": @[@3, @"a", [NSDate date]],
                                 @"Super Property 6":
                                     [NSURL URLWithString:@"https://mixpanel.com"],
                                 @"Super Property 7": [NSNull null]};
    [self.mixpanel registerSuperProperties:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:eventTitle];
}

- (void)testRegisterSuperPropertiesOnce
{
    NSString *eventTitle = @"Register Super Properties Once";
    NSDictionary *properties = @{@"Super Property 1": @2.3};
    [self.mixpanel registerSuperPropertiesOnce:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:eventTitle];
}

- (void)testRegisterSuperPropertiesOnceWithDefaultValue
{
    NSString *eventTitle = @"Register Super Properties Once";
    NSDictionary *properties = @{@"Super Property 1": @1.2};
    [self.mixpanel registerSuperPropertiesOnce:properties defaultValue:@2.3];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties %@ with Default Value: 2.3", properties] title:eventTitle];
}

- (void)testUnRegisterSuperProperty
{
    NSString *eventTitle = @"Unregister Super Properties";
    [self.mixpanel unregisterSuperProperty:@"Super Property 1"];
    
    [self presentLogMessage:[NSString stringWithFormat:@"Unregister Super Properties %@", @"Super Property 1"] title:eventTitle];
}

@end
