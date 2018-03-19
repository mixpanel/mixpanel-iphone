//
//  MixpanelOptOutTests.m
//  HelloMixpanelTests
//
//  Created by Zihe Jia on 3/15/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "TestConstants.h"
#import "MixpanelPeoplePrivate.h"

@interface MixpanelOptOutTests : MixpanelBaseTests

@end

@implementation MixpanelOptOutTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"optOutFlag"];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptOut
{
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptIn
{
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"first, the current user should have opted out tracking");
    [self.mixpanel optInTracking];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted in tracking");
}

- (void)testOptOutTrackingWillNotGenerateEventQueue
{
    stubTrack();
    [self.mixpanel optOutTracking];
    
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"When opted out, people should not be queued");
}

- (void)testOptOutTrackingWillNotGeneratePeopleQueue
{
    stubEngage();
    [self.mixpanel optOutTracking];
    
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 0, @"When opted out, people should not be queued");
}

- (void)testOptOutTrackingWillSkipIdentify
{
    stubEngage();
    [self.mixpanel optOutTracking];
    [self.mixpanel identify:@"d1"];
    //opt in again just to enable people queue
    [self.mixpanel optInTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.people.unidentifiedQueue count] == 50, @"When opted out, people should have been queued");
}

- (void)testOptOutTrackingWillSkipAlias
{
    stubEngage();
    [self.mixpanel optOutTracking];
    [self.mixpanel createAlias:@"testAlias" forDistinctID:@"aDistintID"];
    XCTAssertFalse([self.mixpanel.alias isEqualToString:@"testAlias"], @"When opted out, alias should not be set");
}

- (void)testOptOutTrackingRegisterSuperProperties {
    NSDictionary *p = @{ @"p1": @"a", @"p2": @3, @"p2": [NSDate date] };
    [self.mixpanel optOutTracking];
    [self.mixpanel registerSuperProperties:p];
    [self waitForMixpanelQueues];
    XCTAssertNotEqualObjects([self.mixpanel currentSuperProperties], p, @"When opted out, register super properties should not be successful");
}

- (void)testOptOutTrackingRegisterSuperPropertiesOnce {
    NSDictionary *p = @{ @"p4": @"a" };
    [self.mixpanel optOutTracking];
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForMixpanelQueues];
    XCTAssertNotEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                          @"When opted out, register super properties once should not be successful");
}

- (void)testOptOutWilSkipTimeEvent {
    [self.mixpanel optOutTracking];
    [self.mixpanel track:@"400 Meters"];
    [self waitForMixpanelQueues];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"When opted out, this event should not be timed.");
}

- (void)testOptOutTrackingWillPurgeEventQueue
{
    stubTrack();
    [self.mixpanel optInTracking];
    [self.mixpanel identify:@"d1"];
    
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50, @"When opted in, events should have been queued");
    
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"When opted out, events should have been purged");
}

- (void)testOptOutTrackingWillPurgePeopleQueue
{
    stubEngage();
    [self.mixpanel optInTracking];
    
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 50, @"When opted in, people should have been queued");
    
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 0, @"When opted out, people should have been purged");
}

- (void)testOptOutWillSkipFlushPeople
{
    stubEngage();
    [self.mixpanel optInTracking];
    
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 50, @"When opted in, people should have been queued");
    
    NSMutableArray *peopleQueue = [NSMutableArray arrayWithArray:self.mixpanel.peopleQueue];
    [self.mixpanel optOutTracking];
    self.mixpanel.peopleQueue = [NSMutableArray arrayWithArray:peopleQueue];
    [self.mixpanel flush];
    [self waitForMixpanelQueues];
    
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 50, @"When opted out, people should not be flushed");
}

- (void)testOptOutWillSkipFlushEvent
{
    stubTrack();
    [self.mixpanel optInTracking];
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50, @"When opted in, events should have been queued");
    
    NSMutableArray *eventsQueue = [NSMutableArray arrayWithArray:self.mixpanel.eventsQueue];
    [self.mixpanel optOutTracking];
    self.mixpanel.eventsQueue = [NSMutableArray arrayWithArray:eventsQueue];
    [self.mixpanel flush];
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50, @"When opted out, events should not be flushed");
}

@end
