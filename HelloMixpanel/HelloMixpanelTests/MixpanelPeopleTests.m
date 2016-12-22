//
//  MixpanelPeopleTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "MixpanelPeoplePrivate.h"

@interface MixpanelPeopleTests : MixpanelBaseTests

@end

@implementation MixpanelPeopleTests

#pragma mark - Queue
- (void)testDropUnidentifiedPeopleRecords {
    for (NSInteger i = 0; i < 505; i++) {
        [self.mixpanel.people set:@"i" to:@(i)];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 500);
    
    NSDictionary *r = self.mixpanel.people.unidentifiedQueue.firstObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(5));
    
    r = self.mixpanel.people.unidentifiedQueue.lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
}

- (void)testDropPeopleRecords {
    [self.mixpanel identify:@"d1"];
    for (NSInteger i = 0; i < 505; i++) {
        [self.mixpanel.people set:@"i" to:@(i)];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 500);
    
    NSDictionary *r = self.mixpanel.peopleQueue.firstObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(5));
    
    r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
}

- (void)testPeopleAssertPropertyTypes {
    NSDictionary *p = @{ @"URL": [NSData data] };
    XCTAssertThrows([self.mixpanel.people set:p], @"unsupported property type was allowed");
    XCTAssertThrows([self.mixpanel.people set:@"p1" to:[NSData data]], @"unsupported property type was allowed");
    
    p = @{ @"p1": @"a" }; // increment should require a number
    XCTAssertThrows([self.mixpanel.people increment:p], @"unsupported property type was allowed");
}

- (void)testPeopleAddPushDeviceToken {
    [self.mixpanel identify:@"d1"];
    NSData *token = [@"0123456789abcdef" dataUsingEncoding:NSUTF8StringEncoding];
    [self.mixpanel.people addPushDeviceToken:token];
    [self waitForMixpanelQueues];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$union"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    
    NSArray *a = p[@"$ios_devices"];
    XCTAssertTrue(a.count == 1, @"device token array not set");
    XCTAssertEqualObjects(a.lastObject, @"30313233343536373839616263646566", @"device token not encoded properly");
}

#pragma mark - Operations
- (void)testPeopleSet {
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{ @"p1": @"a" };
    [self.mixpanel.people set:p];
    [self waitForMixpanelQueues];
    
    p = self.mixpanel.peopleQueue.lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleSetOnce {
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel.people setOnce:p];
    [self waitForMixpanelQueues];
    
    p = self.mixpanel.peopleQueue.lastObject[@"$set_once"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleSetReservedProperty {
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{@"$ios_app_version": @"override"};
    [self.mixpanel.people set:p];
    [self waitForMixpanelQueues];
    
    p = self.mixpanel.peopleQueue.lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"$ios_app_version"], @"override", @"reserved property override failed");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleSetTo {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    [self waitForMixpanelQueues];
    
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleIncrement {
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{ @"p1": @3 };
    [self.mixpanel.people increment:p];
    [self waitForMixpanelQueues];
    
    p = self.mixpanel.peopleQueue.lastObject[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
}

- (void)testPeopleIncrementBy
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people increment:@"p1" by:@3];
    [self waitForMixpanelQueues];
    
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
}

- (void)testPeopleDeleteUser
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people deleteUser];
    [self waitForMixpanelQueues];
    
    NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$delete"];
    XCTAssertTrue(p.count == 0, @"incorrect people properties: %@", p);
}

#pragma mark - ($) Charges
- (void)testPeopleTrackChargeDecimal {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people trackCharge:@25.34];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25.34);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
}

- (void)testPeopleTrackChargeNil {
    [self.mixpanel identify:@"d1"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows([self.mixpanel.people trackCharge:nil]);
#pragma clang diagnostic pop
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0);
}

- (void)testPeopleTrackChargeZero {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people trackCharge:@0];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @0);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
}

- (void)testPeopleTrackChargeWithTime {
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = [self allPropertyTypes];
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"$time": p[@"date"]}];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$time"], p[@"date"]);
}

- (void)testPeopleTrackChargeWithProperties {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"p1": @"a"}];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"p1"], @"a");
}

- (void)testPeopleTrackCharge {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people trackCharge:@25];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
}

- (void)testPeopleClearCharges {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people clearCharges];
    [self waitForMixpanelQueues];
    
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"$transactions"], @[]);
}

@end
