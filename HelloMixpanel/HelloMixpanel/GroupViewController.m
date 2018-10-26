//
//  GroupViewController.m
//  HelloMixpanel
//
//  Created by Weizhe Yuan on 8/30/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "GroupViewController.h"

@implementation GroupViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.trackActions = @{@"1.  Set Group" : ^(void){[self testSetGroup];},
                          @"2.  Add Group": ^(void){[self testAddGroup];},
                          @"3.  Remove Group": ^(void){[self testRemoveGroup];},
                          @"4.  Track With Groups": ^(void){[self testTrackWithGroup];},
                          @"5.  Set Group Properties": ^(void){[self testGroupSetProperties];},
                          @"5.  Set Group Properties Once": ^(void){[self testGroupSetPropertiesOnce];},
                          @"6.  Union Group Properties" :^(void){[self testGroupUnionProperties];},
                          @"7.  Unset A Group Property" :^(void){[self testGroupUnsetProperty];},
                          @"8.  Remove A Group Property":^(void){[self testGroupRemoveProperty];},
                          @"9.  Delete Group":^(void){[self testDeleteGroup];}
                          };
    self.trackActionsArray = [self.trackActions.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    [self.tableView reloadData];
}

- (void)testSetGroup
{
    NSArray *groups = @[ @"google", @"facebook" ];
    [self.mixpanel setGroup:@"company" groupIDs:groups];
    [self presentLogMessage:[NSString stringWithFormat:@"Set groups to \"%@\"", groups] title:@"Set Group"];
}

- (void)testAddGroup
{
    NSString *newGroup = @"mixpanel";
    [self.mixpanel addGroup:@"company" groupID:newGroup];
    [self presentLogMessage:[NSString stringWithFormat:@"Add group \"%@\"", newGroup] title:@"Add Group"];
}

- (void)testRemoveGroup
{
    NSString *group = @"mixpanel";
    [self.mixpanel removeGroup:@"company" groupID:group];
    [self presentLogMessage:[NSString stringWithFormat:@"Remove group \"%@\"", group] title:@"Remove Group"];
}

- (void)testTrackWithGroup
{
    NSDictionary *prop = @{@"a" : @1, @"b": @"old_value"};
    NSDictionary *groups = @{@"b" : @"new_value"};
    [self.mixpanel trackWithGroups:@"event_with_groups" properties:prop groups:groups];
    [self presentLogMessage:[NSString stringWithFormat:@"Track with properties %@ and groups %@", prop, groups]
                      title:@"Track With Groups"];
}

- (void)testGroupSetProperties
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    NSDictionary *prop = @{@"prop_int" : @1, @"prop_string" : @"foo", @"prop_list" : @[ @"value" ]};
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group set:prop];
    [self presentLogMessage:[NSString stringWithFormat:@"For group [%@,%@] set properties %@", groupKey, groupID, prop]
                      title:@"Set"];
}

- (void)testGroupSetPropertiesOnce
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    NSDictionary *prop = @{@"prop_int" : @1, @"prop_string" : @"foo"};
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group setOnce:prop];
    [self presentLogMessage:[NSString
                                stringWithFormat:@"For group [%@,%@] set_once properties %@", groupKey, groupID, prop]
                      title:@"Set Once"];
}

- (void)testGroupUnionProperties
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    NSString *key = @"prop_list";
    NSArray *newValues = @[ @"new_value" ];
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group union:key values:newValues];
    [self presentLogMessage:[NSString stringWithFormat:@"For group [%@,%@] union properties {%@:%@}", groupKey, groupID,
                                                       key, newValues]
                      title:@"Union"];
}

- (void)testGroupUnsetProperty
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    NSString *key = @"prop_list";
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group unset:key];
    [self presentLogMessage:[NSString stringWithFormat:@"For group [%@,%@] unset property %@", groupKey, groupID, key]
                      title:@"Unset"];
}

- (void)testGroupRemoveProperty
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    NSString *key = @"prop_list";
    NSString *value = @"new_value";
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group remove:key value:value];
    [self presentLogMessage:[NSString stringWithFormat:@"For group [%@,%@] remove property {%@:%@}", groupKey,
                                                       groupID, key, value]
                      title:@"Remove"];
}

- (void)testDeleteGroup
{
    NSString *groupKey = @"company";
    NSString *groupID = @"mixpanel";
    MixpanelGroup *group = [self.mixpanel getGroup:groupKey groupID:groupID];
    [group deleteGroup];
    [self presentLogMessage:[NSString stringWithFormat:@"Delete group [%@,%@]", groupKey, groupID] title:@"Delete"];
}

@end
