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
    self.trackActions = @{@"Create Alias": ^(void){[self testCreateAlias];},
                          @"Reset": ^(void){[self testReset];},
                          @"Archive": ^(void){[self testArchive];},
                          @"Flush": ^(void){[self testFlush];}
                          };
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
    NSString *eventTitle = @"Create Alias";
    [self.mixpanel createAlias:@"New Alias" forDistinctID:self.mixpanel.distinctId];
    [self presentLogMessage:[NSString stringWithFormat:@"Alias: New Alias, from:  %@", self.mixpanel.distinctId] title:eventTitle];
}

- (void)testReset
{
    NSString *eventTitle = @"Reset";
    [self.mixpanel reset];
    [self presentLogMessage:@"Instance has been reset" title:eventTitle];
}

- (void)testArchive
{
    NSString *eventTitle = @"Archive";
    [self.mixpanel archive];
    [self presentLogMessage:@"Archived Data" title:eventTitle];
}

- (void)testFlush
{
    NSString *eventTitle = @"Flush";
    [self.mixpanel flush];
    [self presentLogMessage:@"Flushed Data" title:eventTitle];
}

@end
