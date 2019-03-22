//
//  MixpanelGroupTests.m
//  HelloMixpanel
//
//  Created by Weizhe Yuan on 8/22/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MixpanelBaseTests.h"
#import "MixpanelGroup.h"
#import "MixpanelGroupPrivate.h"
#import "MixpanelPeoplePrivate.h"
#import "MixpanelPrivate.h"
#import "TestConstants.h"

@interface MixpanelGroupTests : MixpanelBaseTests

@end

@implementation MixpanelGroupTests

- (void)setUp
{
    [super setUp];
    stubGroups();
}

- (void)testTrackWithGroups
{
    NSDictionary *p = @{@"token" : @"t1", @"distinct_id" : @"d1", @"key" : @"id1"};
    NSDictionary *g = @{@"key" : @"id2"};
    [self.mixpanel trackWithGroups:@"e1" properties:p groups:g];
    [self waitForMixpanelQueues];

    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"properties"][@"key"], @"id2",
                          @"groups should overwrite properties");
}

- (void)testGetGroup
{
    MixpanelGroup *g1 = [self.mixpanel getGroup:@"key1" groupID:@"id"];
    MixpanelGroup *g2 = [self.mixpanel getGroup:@"key1" groupID:@"id"];
    XCTAssertEqual(g1, g2);
    XCTAssertEqual(g1.groupKey, @"key1");
    XCTAssertEqual(g1.groupID, @"id");

    MixpanelGroup *g3 = [self.mixpanel getGroup:@"key2" groupID:@"id1"];
    MixpanelGroup *g4 = [self.mixpanel getGroup:@"key2" groupID:@"id2"];
    XCTAssertNotEqual(g3, g4);
}

- (void)testGetGroupCacheCollision
{
    MixpanelGroup *g1 = [self.mixpanel getGroup:@"key_collision" groupID:@"happens"];
    MixpanelGroup *g2 = [self.mixpanel getGroup:@"key" groupID:@"collision_happens"];
    XCTAssertNotEqual(g1, g2);
}

- (void)testSetGroup
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel setGroup:@"p1" groupID:@"a"];
    [self.mixpanel track:@"ev"];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @[ @"a" ]);
    XCTAssertEqualObjects(self.mixpanel.currentSuperProperties[@"p1"], @[ @"a" ]);

    p = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(p[@"properties"][@"p1"], @[ @"a" ], "all following tracks should have new property 'p1'");
}

- (void)testAddGroupBasic
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel addGroup:@"key" groupID:@"id1"];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$union"];
    XCTAssertEqualObjects(p[@"key"], @[ @"id1" ]);
    XCTAssertEqualObjects(self.mixpanel.currentSuperProperties[@"key"], @[ @"id1" ]);
}

- (void)testAddGroupIgnoreExistingValue
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel addGroup:@"key" groupID:@"id1"];
    [self.mixpanel addGroup:@"key" groupID:@42];
    [self.mixpanel addGroup:@"key" groupID:@"id1"];
    [self waitForMixpanelQueues];
    NSArray *expected = @[ @"id1", @42];
    XCTAssertEqualObjects(self.mixpanel.currentSuperProperties[@"key"], expected);
}

- (void)testRemoveGroupBasic
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel setGroup:@"key" groupIDs:@[@"id"]];
    [self.mixpanel removeGroup:@"key" groupID:@"id"];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$remove"];
    XCTAssertEqualObjects(p[@"key"], @"id", @"custom group property not queued");
}

- (void)testRemoveGroupIgnoreNonExistingValue
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel setGroup:@"key" groupIDs:@[ @"id1", @"id2", @"id3" ]];
    [self.mixpanel removeGroup:@"key" groupID:@"id1"];
    [self.mixpanel removeGroup:@"key" groupID:@"id1"];
    [self.mixpanel removeGroup:@"key" groupID:@"id2"];
    [self.mixpanel removeGroup:@"key" groupID:@"id4"];
    [self waitForMixpanelQueues];
    XCTAssertEqualObjects(self.mixpanel.currentSuperProperties[@"key"], @[ @"id3" ]);
}

- (void)testGroupSet
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g set:@{@"foo" : @"bar"}];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    NSDictionary *set = p[@"$set"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(set[@"foo"], @"bar");
}

- (void)testGroupSetOnce
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g setOnce:@{@"foo" : @"bar"}];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    NSDictionary *set_once = p[@"$set_once"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(set_once[@"foo"], @"bar");
}

- (void)testGroupUnion
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g union:@"foo" values:@[ @"bar" ]];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    NSDictionary *union_ = p[@"$union"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(union_[@"foo"], @[ @"bar" ]);
}

- (void)testGroupUnset
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g unset:@"foo"];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    NSDictionary *unset = p[@"$unset"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(unset, @[ @"foo" ]);
}

- (void)testGroupDelete
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g deleteGroup];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    NSObject *delete = p[@"$delete"];
    XCTAssertNotNil(delete);
}

- (void)testGroupRemove
{
    MixpanelGroup *g = [self.mixpanel getGroup:@"key" groupID:@"id"];
    [g remove:@"foo" value:@"bar"];
    [self waitForMixpanelQueues];
    NSDictionary *p = self.mixpanel.groupsQueue.lastObject;
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    NSDictionary *remove = p[@"$remove"];
    XCTAssertEqualObjects(remove[@"foo"], @"bar");
}

@end
