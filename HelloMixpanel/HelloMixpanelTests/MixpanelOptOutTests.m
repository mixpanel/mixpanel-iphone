//
//  MixpanelOptOutTests.m
//  HelloMixpanelTests
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "TestConstants.h"
#import "MixpanelPeoplePrivate.h"


@interface MixpanelOptOutTests : MixpanelBaseTests

@end

@implementation MixpanelOptOutTests

- (NSString *)randomTokenId {
    return [NSString stringWithFormat:@"%08x%08x", arc4random(), arc4random()];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES
{
    NSString *testToken = [self randomTokenId];
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:testToken trackAutomaticEvents:YES optOutTrackingByDefault:YES];
    
    XCTAssertTrue([testMixpanel hasOptedOutTracking], @"When initialize with opted out flag set to YES, the current user should have opted out tracking");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptInWillAddOptInEvent
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel optInTracking];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    [self waitForMixpanelQueues:testMixpanel];
    if ([[self eventQueue:testMixpanel.apiToken] count] == 1) {
        NSDictionary *event = [self eventQueue:testMixpanel.apiToken].firstObject;
        XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
    }
    else {
        XCTAssertTrue([[self eventQueue:testMixpanel.apiToken] count] == 0, @"When opted in, event queue should have one even(opt in) being queued");
    }
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptInTrackingForDistinctID
{
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel optInTrackingForDistinctID:@"testDistinctId"];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    
    [self waitForMixpanelQueues:testMixpanel];

    NSDictionary *event = [self eventQueue:testMixpanel.apiToken].firstObject;
    if (![event[@"event"] isEqualToString:@"$opt_in"]) {
        event = [self eventQueue:testMixpanel.apiToken][1];
    }
    XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
   
    XCTAssertEqualObjects(testMixpanel.distinctId, @"testDistinctId", @"mixpanel identify failed to set distinct id");
    XCTAssertEqualObjects(testMixpanel.people.distinctId, @"testDistinctId", @"mixpanel identify failed to set people distinct id");
    XCTAssertTrue([self unIdentifiedPeopleQueue:testMixpanel.apiToken].count == 0, @"identify: should move records from unidentified queue");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptInTrackingForDistinctIDAndWithEventProperties
{    
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDate *now = [NSDate date];
    NSDictionary *p = @{ @"string": @"yello",
                         @"number": @3,
                         @"date": now,
                         @"$app_version": @"override" };
    [testMixpanel optInTrackingForDistinctID:@"testDistinctId" withEventProperties:p];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    
    [self waitForMixpanelQueues:testMixpanel];
    NSArray *eventQueue = [self eventQueue:testMixpanel.apiToken];
    NSDictionary *props = eventQueue[0][@"properties"];
    if (props[@"string"] == nil) {
        props = eventQueue[1][@"properties"];
    }
    XCTAssertEqualObjects(props[@"string"], @"yello");
    XCTAssertEqualObjects(props[@"number"], @3);
    XCTAssertTrue([self isDateString:props[@"date"] equalToDate:now]);
    XCTAssertTrue([props[@"$app_version"] isEqualToString:@"override"], @"reserved property override failed");
    
    if (eventQueue.count == 2) {
        NSDictionary *event = [self eventQueue:testMixpanel.apiToken].firstObject;
        if (![event[@"event"] isEqualToString:@"$opt_in"]) {
            event = [self eventQueue:testMixpanel.apiToken][1];
        }
        XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
    }
    else {
        XCTAssertTrue([[self eventQueue:testMixpanel.apiToken] count] == 2, @"When opted in, event queue should have one even(opt in) being queued and $identify call");
    }
    
    XCTAssertEqualObjects(testMixpanel.distinctId, @"testDistinctId", @"mixpanel identify failed to set distinct id");
    XCTAssertEqualObjects(testMixpanel.people.distinctId, @"testDistinctId", @"mixpanel identify failed to set people distinct id");
    XCTAssertTrue([self unIdentifiedPeopleQueue:testMixpanel.apiToken].count == 0, @"identify: should move records from unidentified queue");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances
{
    Mixpanel *mixpanel1 = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES optOutTrackingByDefault:YES];
    XCTAssertTrue([mixpanel1 hasOptedOutTracking], @"When initialize with opted out flag set to YES, the current user should have opted out tracking");
    
    Mixpanel *mixpanel2 = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES optOutTrackingByDefault:NO];
    XCTAssertFalse([mixpanel2 hasOptedOutTracking], @"When initialize with opted out flag set to NO, the current user should have opted in tracking");
    
    [self removeDBfile:mixpanel1.apiToken];
    [self removeDBfile:mixpanel2.apiToken];

}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES optOutTrackingByDefault:NO];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"When initialize with opted out flag set to NO, the current user should have opted out tracking");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyByDefault
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"By default, the current user should not opted out tracking");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptOut
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    [testMixpanel optOutTracking];
    XCTAssertTrue([testMixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted out tracking");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptIn
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    [testMixpanel optOutTracking];
    XCTAssertTrue([testMixpanel hasOptedOutTracking], @"By calling optOutTracking, the current user should have opted out tracking");
    [testMixpanel optInTracking];
    XCTAssertFalse([testMixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted in tracking");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingWillNotGenerateEventQueue
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:NO];
    [testMixpanel optOutTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [testMixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([[self eventQueue:testMixpanel.apiToken] count] == 0, @"When opted out, events should not be queued");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingWillNotGeneratePeopleQueue
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:NO];
    [testMixpanel identify:@"d1"];
    [testMixpanel optOutTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [testMixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([[self peopleQueue:testMixpanel.apiToken] count] == 0, @"When opted out, people should not be queued");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingWillSkipIdentify
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:NO];
    [testMixpanel optOutTracking];
    [testMixpanel identify:@"d1"];
    //opt in again just to enable people queue
    [testMixpanel optInTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [testMixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([[self unIdentifiedPeopleQueue:testMixpanel.apiToken] count] == 50, @"When opted out, calling identify should be skipped");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingWillSkipAlias
{
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    [testMixpanel optOutTracking];
    [testMixpanel createAlias:@"testAlias" forDistinctID:@"aDistinctID"];
    XCTAssertFalse([testMixpanel.alias isEqualToString:@"testAlias"], @"When opted out, alias should not be set");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingRegisterSuperProperties {
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    NSDictionary *p = @{ @"p1": @"a", @"p2": @3, @"p3": [NSDate date] };
    [testMixpanel optOutTracking];
    [testMixpanel registerSuperProperties:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertNotEqualObjects([testMixpanel currentSuperProperties], p, @"When opted out, register super properties should not be successful");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutTrackingRegisterSuperPropertiesOnce {
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    NSDictionary *p = @{ @"p4": @"a" };
    [testMixpanel optOutTracking];
    [testMixpanel registerSuperPropertiesOnce:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertNotEqualObjects([testMixpanel currentSuperProperties][@"p4"], @"a",
                          @"When opted out, register super properties once should not be successful");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testOptOutWilSkipTimeEvent {
    Mixpanel *testMixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] trackAutomaticEvents:YES];
    [testMixpanel optOutTracking];
    [testMixpanel timeEvent:@"400 Meters"];
    [testMixpanel track:@"400 Meters"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"When opted out, this event should not be timed.");
    [self removeDBfile:testMixpanel.apiToken];
}


@end
