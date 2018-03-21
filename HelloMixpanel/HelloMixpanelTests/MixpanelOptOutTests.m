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

- (void)tearDown
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *filename = [self.mixpanel optOutFilePath];
    [manager removeItemAtPath:filename error:&error];
    [super tearDown];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES
{
    Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"abc123Random" optOutTracking:YES];
    XCTAssertTrue([mixpanel hasOptedOutTracking], @"When initialize with opted out flag set to YES, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO
{
    Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"abc123Radd" optOutTracking:NO];
    XCTAssertFalse([mixpanel hasOptedOutTracking], @"When initialize with opted out flag set to NO, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyByDefault
{
    Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"abc123"];
    XCTAssertFalse([mixpanel hasOptedOutTracking], @"By default, the current user should not opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptOut
{
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptIn
{
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"By calling optOutTracking, the current user should have opted out tracking");
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
    XCTAssertTrue([self.mixpanel.people.unidentifiedQueue count] == 50, @"When opted out, calling identify should be skipped");
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
    stubTrack();
    [self.mixpanel optOutTracking];
    [self.mixpanel timeEvent:@"400 Meters"];
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
    [self waitForMixpanelQueues];
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
    [self waitForMixpanelQueues];
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
    
    //In order to test if flush will be skipped, we have to create a fake peopleQueue since optOutTracking will clear peopleQueue.
    [self waitForMixpanelQueues];
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
   
    //In order to test if flush will be skipped, we have to create a fake eventsQueue since optOutTracking will clear eventsQueue.
    [self waitForMixpanelQueues];
    self.mixpanel.eventsQueue = [NSMutableArray arrayWithArray:eventsQueue];
    
    [self.mixpanel flush];
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50, @"When opted out, events should not be flushed");
}

@end
