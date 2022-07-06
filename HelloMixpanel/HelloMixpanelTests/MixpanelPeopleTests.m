//
//  MixpanelPeopleTests.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "MixpanelPeoplePrivate.h"

@interface MixpanelPeopleTests : MixpanelBaseTests

@end

@implementation MixpanelPeopleTests

#pragma mark - Queue
- (void)testDropUnidentifiedPeopleRecords {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    
    for (NSInteger i = 0; i < 505; i++) {
        [testMixpanel.people set:@"i" to:@(i)];
    }
    
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self unIdentifiedPeopleQueue:testMixpanel.apiToken].count == 505);
    
    NSDictionary *r = [self unIdentifiedPeopleQueue:testMixpanel.apiToken][0];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(0));
    
    r = [self unIdentifiedPeopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testDropPeopleRecords {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    for (NSInteger i = 0; i < 505; i++) {
        [testMixpanel.people set:@"i" to:@(i)];
    }
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 505);
    
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken][0];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(0));
    
    r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleAssertPropertyTypes {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    NSDictionary *p = @{ @"URL": [NSData data] };
    XCTAssertThrows([testMixpanel.people set:p], @"unsupported property type was allowed");
    XCTAssertThrows([testMixpanel.people set:@"p1" to:[NSData data]], @"unsupported property type was allowed");
    
    p = @{ @"p1": @"a" }; // increment should require a number
    XCTAssertThrows([testMixpanel.people increment:p], @"unsupported property type was allowed");
    [self removeDBfile:testMixpanel.apiToken];
}

#pragma mark - Operations
- (void)testPeopleSet {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    NSDictionary *p = @{ @"p1": @"a" };
    [testMixpanel.people set:p];
    [self waitForMixpanelQueues:testMixpanel];
    p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleSetOnce {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    NSDictionary *p = @{@"p1": @"a"};
    [testMixpanel.people setOnce:p];
    [self waitForMixpanelQueues:testMixpanel];
    p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set_once"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleSetReservedProperty {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    NSDictionary *p = @{@"$ios_app_version": @"override"};
    [testMixpanel.people set:p];
    [self waitForMixpanelQueues:testMixpanel];
    
    p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"$ios_app_version"], @"override", @"reserved property override failed");
    [self assertDefaultPeopleProperties:p];
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleSetTo {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people set:@"p1" to:@"a"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleIncrement {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    NSDictionary *p = @{ @"p1": @3 };
    [testMixpanel.people increment:p];
    [self waitForMixpanelQueues:testMixpanel];
    p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleIncrementBy
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people increment:@"p1" by:@3];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleDeleteUser
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people deleteUser];
    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$delete"];
    XCTAssertTrue(p.count == 0, @"incorrect people properties: %@", p);
    [self removeDBfile:testMixpanel.apiToken];
}

#pragma mark - ($) Charges
- (void)testPeopleTrackChargeDecimal {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people trackCharge:@25.34];
    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25.34);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleTrackChargeNil {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows([testMixpanel.people trackCharge:nil]);
#pragma clang diagnostic pop
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleTrackChargeZero {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people trackCharge:@0];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @0);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleTrackChargeWithTime {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    NSDictionary *p = [self allPropertyTypes];
    [testMixpanel.people trackCharge:@25 withProperties:@{@"$time": p[@"date"]}];
    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertTrue([self isDateString:r[@"$append"][@"$transactions"][@"$time"] equalToDate:p[@"date"]]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleTrackChargeWithProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people trackCharge:@25 withProperties:@{@"p1": @"a"}];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"p1"], @"a");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleTrackCharge {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people trackCharge:@25];
    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testPeopleClearCharges {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents: YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel.people clearCharges];
    [self waitForMixpanelQueues:testMixpanel];
    
    NSDictionary *r = [self peopleQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"$transactions"], @[]);
    [self removeDBfile:testMixpanel.apiToken];
}

@end
