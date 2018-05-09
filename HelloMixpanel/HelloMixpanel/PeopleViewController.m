//
//  PeopleViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/4/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//
#import "PeopleViewController.h"


@interface PeopleViewController ()

@end

@implementation PeopleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.trackActions = @{@"1.  Set Properties": ^(void){[self testSetProperties];},
                          @"2.  Set One Property": ^(void){[self testSetOneProperty];},
                          @"3.  Set Properties Once": ^(void){[self testSetPropertiesOnce];},
                          @"4.  Unset Properties": ^(void){[self testUnsetProperties];},
                          @"5.  Incremet Properties": ^(void){[self testIncrementProperties];},
                          @"6.  Increment Property": ^(void){[self testIncrementProperty];},
                          @"7.  Append Properties": ^(void){[self testAppendProperties];},
                          @"8.  Union Properties": ^(void){[self testUnionProperties];},
                          @"9.  Track Charge w/o Properties": ^(void){[self testTrackChargeWithOutProperties];},
                          @"10. Track Charge w Properties": ^(void){[self testTrackChargeWithProperties];},
                          @"11. Clear Charges": ^(void){[self testClearCharges];},
                          @"12. Delete User": ^(void){[self testDeleteUsers];},
                          @"13. Identify": ^(void){[self testIdentify];}
                          };
    self.trackActionsArray = [self.trackActions.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self.tableView reloadData];
}

- (void)testSetProperties
{
    NSDictionary *properties = @{@"a": @1,
                                @"b": @2.3,
                                @"c": @[@"4", @5],
                                @"d": [NSURL URLWithString:@"https://mixpanel.com"],
                                @"e": [NSNull null],
                                 @"f":  [NSDate date]};
    
    [self.mixpanel.people set:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Set Properties"];
}

- (void)testSetOneProperty
{
    [self.mixpanel.people set:@"g" to:@"yo"];
    [self presentLogMessage:@"Property key: g, value: yo" title:@"Set One Property"];
}

- (void)testSetPropertiesOnce
{
    NSDictionary *properties = @{@"h": @"just once"};
    
    [self.mixpanel.people setOnce:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Set Properties Once"];
}

- (void)testUnsetProperties
{
    NSArray *keys = @[@"a", @"b"];
    
    [self.mixpanel.people unset:keys];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", keys] title:@"Unset Properties"];
}

- (void)testIncrementProperties
{
    NSDictionary *properties = @{@"a": @1.2, @"b": @3};
    
    [self.mixpanel.people increment:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Increment Properties: %@", properties] title:@"Increment Properties"];
}

- (void)testIncrementProperty
{
    [self.mixpanel.people increment:@"b" by:@2.3];
    [self presentLogMessage:@"Property key: b, value increment: 2.3" title:@"Increment Property"];
}

- (void)testAppendProperties
{
    NSDictionary *properties = @{@"c": @"hello", @"d": @"goodbye"};
    
    [self.mixpanel.people append:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Append Properties"];
}

- (void)testUnionProperties
{
    NSDictionary *properties = @{@"c": @[@"goodbye", @"hi"], @"d": @"hello"};
    
    [self.mixpanel.people union:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Properties: %@", properties] title:@"Union Properties"];
}

- (void)testTrackChargeWithOutProperties
{
    [self.mixpanel.people trackCharge:@20.5];
    [self presentLogMessage:@"Amount: 20.5" title:@"Track Charge"];
}

- (void)testTrackChargeWithProperties
{
    NSDictionary *properties = @{@"sandwich": @1};
    [self.mixpanel.people trackCharge:@12.8 withProperties:properties];
    [self presentLogMessage:[NSString stringWithFormat:@"Amount: 12.8, Properties: %@", properties] title:@"Track Charge With Properties"];
}

- (void)testClearCharges
{
    [self.mixpanel.people clearCharges];
    [self presentLogMessage:@"Cleared Charges" title:@"Clear Charges"];
}

- (void)testDeleteUsers
{
    [self.mixpanel.people deleteUser];
    [self presentLogMessage:@"Deleted User" title:@"Delete User"];
}

- (void)testIdentify
{
    // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
    // we're using the automatically generated distinct ID from event tracking, based on the device's MAC address.
    // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
    // Note that the call to Mixpanel People identify: can come after properties have been set. We queue them until
    // identify: is called and flush them at that time. That way, you can set properties before a user is logged in
    // and identify them once you know their user ID.
    [self.mixpanel identify:self.mixpanel.distinctId];
    [self presentLogMessage:@"Identified" title:@"Identify"];
}

@end
