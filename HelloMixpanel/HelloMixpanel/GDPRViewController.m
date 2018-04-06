//
//  GDPRViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/5/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "GDPRViewController.h"

@interface GDPRViewController ()

@end

@implementation GDPRViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.trackActions = @{@"1. Opt Out": ^(void){[self testOptOut];},
                          @"2. Check Has Opted Out": ^(void){[self testHasOptedOut];},
                          @"3. Opt In": ^(void){[self testOptIn];},
                          @"4. Opt In w DistinctId": ^(void){[self testOptInWithDistinctId];},
                          @"5. Opt In w DistinctId & Properties": ^(void){[self testOptInWithDistinctIdProperties];}};
    self.trackActionsArray = [self.trackActions.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self.tableView reloadData];
}

- (void)testOptOut
{
    NSString *eventTitle = @"Opt Out";
    [self.mixpanel optOutTracking];
    [self presentLogMessage:@"Opted out" title:eventTitle];
}

- (void)testHasOptedOut
{
    NSString *eventTitle = @"Test Has Opted Out";
    if ([self.mixpanel hasOptedOutTracking]) {
        [self presentLogMessage:@"Opted Out is 'True'" title:eventTitle];
    }
    else {
        [self presentLogMessage:@"Opted Out is 'False'" title:eventTitle];
    }
}

- (void)testOptIn
{
    NSString *eventTitle = @"Opt In";
    [self.mixpanel optInTracking];
    [self presentLogMessage:@"Opted in" title:eventTitle];
}

- (void)testOptInWithDistinctId
{
    NSString *eventTitle = @"Opt In With DistinctId";
    [self.mixpanel optInTrackingForDistinctID:@"aDistinctIdForOptIn"];
    [self presentLogMessage:@"Opted in with distinctId: aDistinctIdForOptIn" title:eventTitle];
}

- (void)testOptInWithDistinctIdProperties
{
    NSString *eventTitle = @"Opt In With DistinctId";
    NSDictionary *p = @{@"string": @"yello",
                         @"number": @3,
                         @"date": [NSDate date],
                         @"$app_version": @"override"};
    [self.mixpanel optInTrackingForDistinctID:@"aDistinctIdForOptIn" withEventProperties:p];
    [self presentLogMessage:[NSString stringWithFormat:@"Opted in with distinctId: aDistinctIdForOptIn, properties: %@", p] title:eventTitle];
}

@end
