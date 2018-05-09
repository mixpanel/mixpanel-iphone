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
                          @"2. Reset": ^(void){[self testReset];},
                          @"3. Archive": ^(void){[self testArchive];},
                          @"4. Flush": ^(void){[self testFlush];}
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

@end
