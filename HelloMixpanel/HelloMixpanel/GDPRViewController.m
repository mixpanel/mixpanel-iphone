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
                          @"2. Check Opt-out Flag": ^(void){[self testHasOptedOut];},
                          @"3. Opt In": ^(void){[self testOptIn];},
                          @"4. Opt In w DistinctId": ^(void){[self testOptInWithDistinctId];},
                          @"5. Opt In w DistinctId & Properties": ^(void){[self testOptInWithDistinctIdProperties];},
                          @"6. Init with default opt-out": ^(void){[self testInitWithDefaultOptOut];},
                          @"6. Init with default opt-in": ^(void){[self testInitWithDefaultOptIn];}
                          };
    self.trackActionsArray = [self.trackActions.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self.tableView reloadData];
}

- (void)testOptOut
{
    [self.mixpanel optOutTracking];
    [self presentLogMessage:@"Opted out" title:@"Opt Out"];
}

- (void)testHasOptedOut
{
    if ([self.mixpanel hasOptedOutTracking]) {
        [self presentLogMessage:@"Opt-out is 'True'" title:@"Test Has Opted Out"];
    }
    else {
        [self presentLogMessage:@"Opt-out is 'False'" title:@"Test Has Opted Out"];
    }
}

- (void)testOptIn
{
    [self.mixpanel optInTracking];
    [self presentLogMessage:@"Opted In" title:@"Opt In"];
}

- (void)testOptInWithDistinctId
{
    [self.mixpanel optInTrackingForDistinctID:@"aDistinctIdForOptIn"];
    [self presentLogMessage:@"Opted in with distinctId: aDistinctIdForOptIn" title:@"Opt In With DistinctId"];
}

- (void)testOptInWithDistinctIdProperties
{
    NSDictionary *p = @{@"string": @"yello",
                         @"number": @3,
                         @"date": [NSDate date],
                         @"$app_version": @"override"};
    [self.mixpanel optInTrackingForDistinctID:@"aDistinctIdForOptIn" withEventProperties:p];
    [self presentLogMessage:[NSString stringWithFormat:@"Opted in with distinctId: aDistinctIdForOptIn, properties: %@", p] title:@"Opt In With DistinctId"];
}

- (void)testInitWithDefaultOptOut
{
    self.mixpanel = [Mixpanel sharedInstanceWithToken:@"a token id" optOutTrackingByDefault:YES];
    [self presentLogMessage:@"Init Mixpanel with default opt-out(sample only), to make it work, place it in your startup stage of your app" title:@"Init Mixpanel with default opt-out"];
}

- (void)testInitWithDefaultOptIn
{
    self.mixpanel = [Mixpanel sharedInstanceWithToken:@"a token id" optOutTrackingByDefault:NO];
    [self presentLogMessage:@"Init Mixpanel with default opt-out(sample only), to make it work, place it in your startup stage of your app" title:@"Init Mixpanel with default opt-out"];
}

@end
