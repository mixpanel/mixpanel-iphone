//
//  MixpanelGroupTests.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
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


- (void)testTrackWithGroups
{
    NSDictionary *p = @{@"token" : @"t1", @"distinct_id" : @"d1", @"key" : @"id1"};
    NSDictionary *g = @{@"key" : @"id2"};
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel trackWithGroups:@"e1" properties:p groups:g];
    [self waitForMixpanelQueues:testMixpanel];

    XCTAssertEqualObjects([self eventQueue:testMixpanel.apiToken].lastObject[@"properties"][@"key"], @"id2",
                          @"groups should overwrite properties");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGetGroup
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g1 = [testMixpanel getGroup:@"key1" groupID:@"id"];
    MixpanelGroup *g2 = [testMixpanel getGroup:@"key1" groupID:@"id"];
    XCTAssertEqual(g1, g2);
    XCTAssertEqual(g1.groupKey, @"key1");
    XCTAssertEqual(g1.groupID, @"id");

    MixpanelGroup *g3 = [testMixpanel getGroup:@"key2" groupID:@"id1"];
    MixpanelGroup *g4 = [testMixpanel getGroup:@"key2" groupID:@"id2"];
    XCTAssertNotEqual(g3, g4);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGetGroupCacheCollision
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g1 = [testMixpanel getGroup:@"key_collision" groupID:@"happens"];
    MixpanelGroup *g2 = [testMixpanel getGroup:@"key" groupID:@"collision_happens"];
    XCTAssertNotEqual(g1, g2);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testSetGroup
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel setGroup:@"p1" groupID:@"a"];
    [testMixpanel track:@"ev"];
    [self waitForMixpanelQueues:testMixpanel];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @[ @"a" ]);
    XCTAssertEqualObjects(testMixpanel.currentSuperProperties[@"p1"], @[ @"a" ]);

    p = [self eventQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(p[@"properties"][@"p1"], @[ @"a" ], "all following tracks should have new property 'p1'");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testAddGroupBasic
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel addGroup:@"key" groupID:@"id1"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$union"];
    XCTAssertEqualObjects(p[@"key"], @[ @"id1" ]);
    XCTAssertEqualObjects(testMixpanel.currentSuperProperties[@"key"], @[ @"id1" ]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testAddGroupIgnoreExistingValue
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel addGroup:@"key" groupID:@"id1"];
    [testMixpanel addGroup:@"key" groupID:@42];
    [testMixpanel addGroup:@"key" groupID:@"id1"];
    [self waitForMixpanelQueues:testMixpanel];
    NSArray *expected = @[ @"id1", @42];
    XCTAssertEqualObjects(testMixpanel.currentSuperProperties[@"key"], expected);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testRemoveGroupBasic
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel setGroup:@"key" groupIDs:@[@"id"]];
    [testMixpanel removeGroup:@"key" groupID:@"id"];
    dispatch_sync(testMixpanel.serialQueue, ^{
        return;
    });

    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertNotNil(p[@"$remove"]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testRemoveGroupIgnoreNonExistingValue
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel setGroup:@"key" groupIDs:@[ @"id1", @"id2", @"id3" ]];
    [testMixpanel removeGroup:@"key" groupID:@"id1"];
    [testMixpanel removeGroup:@"key" groupID:@"id1"];
    [testMixpanel removeGroup:@"key" groupID:@"id2"];
    [testMixpanel removeGroup:@"key" groupID:@"id4"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects(testMixpanel.currentSuperProperties[@"key"], @[ @"id3" ]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupSet
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g set:@{@"foo" : @"bar"}];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *set = p[@"$set"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(set[@"foo"], @"bar");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupSetOnce
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g setOnce:@{@"foo" : @"bar"}];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *set_once = p[@"$set_once"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(set_once[@"foo"], @"bar");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupUnion
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g union:@"foo" values:@[ @"bar" ]];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *union_ = p[@"$union"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(union_[@"foo"], @[ @"bar" ]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupUnset
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g unset:@"foo"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *unset = p[@"$unset"];
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    XCTAssertEqualObjects(unset, @[ @"foo" ]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupDelete
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g deleteGroup];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    NSObject *delete = p[@"$delete"];
    XCTAssertNotNil(delete);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testGroupRemove
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    MixpanelGroup *g = [testMixpanel getGroup:@"key" groupID:@"id"];
    [g remove:@"foo" value:@"bar"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self groupQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(p[@"$group_key"], @"key");
    XCTAssertEqualObjects(p[@"$group_id"], @"id");
    NSDictionary *remove = p[@"$remove"];
    XCTAssertEqualObjects(remove[@"foo"], @"bar");
    [self removeDBfile:testMixpanel.apiToken];
}

@end
