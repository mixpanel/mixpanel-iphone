//
//  UtilityViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/4/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "UtilityViewController.h"

@interface UtilityViewController ()

@end

@implementation UtilityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.trackActions = @{@"1. Create Alias": ^(void){[self testCreateAlias];},
                          @"2. Identify": ^(void){[self testIdentify];},
                          @"3. Reset": ^(void){[self testReset];},
                          @"4. Archive": ^(void){[self testArchive];},
                          @"5. Flush": ^(void){[self testFlush];}
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

- (void)testCreateAlias
{
    [self.mixpanel createAlias:@"New Alias" forDistinctID:self.mixpanel.distinctId];
    [self presentLogMessage:[NSString stringWithFormat:@"Alias: New Alias, from:  %@", self.mixpanel.distinctId] title:@"Create Alias"];
}

- (void)testReset
{
    [self.mixpanel reset];
    [self presentLogMessage:@"Instance has been reset" title:@"Reset"];
}

- (void)testArchive
{
    [self.mixpanel archive];
    [self presentLogMessage:@"Archived Data" title:@"Archive"];
}

- (void)testFlush
{
    [self.mixpanel flush];
    [self presentLogMessage:@"Flushed Data" title:@"Flush"];
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
    [self presentLogMessage:@"Flushed Data" title:@"Identify"];
}

@end
