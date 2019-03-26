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
#import <OCMock/OCMock.h>

@interface MixpanelOptOutTests : MixpanelBaseTests

@end

@implementation MixpanelOptOutTests

- (NSString *)randomTokenId {
    return [NSString stringWithFormat:@"%08x%08x", arc4random(), arc4random()];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES
{
    stubTrack();
    stubEngage();
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] optOutTrackingByDefault:YES];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"When initialize with opted out flag set to YES, the current user should have opted out tracking");
}

- (void)testNoTrackShouldEverBeTriggeredDuringInitializedWithOptedOutYES
{
    stubTrack();
    stubEngage();
    __block NSInteger trackCount = 0;
    [MPSwizzler swizzleSelector:@selector(track:) onClass:[Mixpanel class] withBlock:^(id obj, SEL sel){
        trackCount++;  
    } named:@"Swizzle Mixpanel.track"];
    
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] optOutTrackingByDefault:YES];
    XCTAssertTrue(trackCount == 0, @"When opted out, no track call should be ever triggered during initialization.");
    
    [MPSwizzler unswizzleSelector:@selector(track:) onClass:[Mixpanel class] named:@"Swizzle Mixpanel.track"];
}

- (void)testTrackShouldBeTriggeredDuringInitializedWithOptedOutYESButPrevouslyOptedIn
{
    stubTrack();
    stubEngage();
    __block NSInteger trackCount = 0;
    [MPSwizzler swizzleSelector:@selector(track:) onClass:[Mixpanel class] withBlock:^(id obj, SEL sel){
        trackCount++;
    } named:@"Swizzle Mixpanel.track"];
    
    NSString *tokenId = [self randomTokenId];
    self.mixpanel = [Mixpanel sharedInstanceWithToken:tokenId optOutTrackingByDefault:YES];
    [self.mixpanel optInTracking];
    
    self.mixpanel = [Mixpanel sharedInstanceWithToken:tokenId optOutTrackingByDefault:YES];
    [self.mixpanel track:@"test"];
    XCTAssertTrue(trackCount == 1, @"init default opted out->optedIn->init default opted out, track call should be triggered during initialization.");
    
    [MPSwizzler unswizzleSelector:@selector(track:) onClass:[Mixpanel class] named:@"Swizzle Mixpanel.track"];
}

- (void)testAutoTrackEventsShouldNotBeQueuedDuringInitializedWithOptedOutYES
{
    stubTrack();
    stubEngage();
    __block NSInteger trackCount = 0;
    [MPSwizzler swizzleSelector:@selector(track:) onClass:[Mixpanel class] withBlock:^(id obj, SEL sel){
        trackCount++;
    } named:@"Swizzle Mixpanel.track"];
    
    NSDictionary *launchOptions = @{ UIApplicationLaunchOptionsRemoteNotificationKey: @{
                                             @"mp": @{
                                                     @"m": @"the_message_id",
                                                     @"c": @"the_campaign_id",
                                                     @"journey_id": @123456
                                                     }
                                             }
                                     };
    
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] launchOptions:launchOptions trackCrashes:YES automaticPushTracking:YES optOutTrackingByDefault:YES];
    [self waitForMixpanelQueues];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"no event should be queued");
    XCTAssertTrue(trackCount == 0, @"When opted out, no track call should be ever triggered during initialization.");
    
    [MPSwizzler unswizzleSelector:@selector(track:) onClass:[Mixpanel class] named:@"Swizzle Mixpanel.track"];
}

- (void)testAutoTrackShouldBeTriggeredDuringInitializedWithOptedOutNO
{
    stubTrack();
    stubEngage();
    NSDictionary *launchOptions = @{ UIApplicationLaunchOptionsRemoteNotificationKey: @{
                                             @"mp": @{
                                                     @"m": @"the_message_id",
                                                     @"c": @"the_campaign_id",
                                                     @"journey_id": @123456
                                                     }
                                             }
                                     };
    
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] launchOptions:launchOptions trackCrashes:YES automaticPushTracking:YES optOutTrackingByDefault:NO];
    [self waitForMixpanelQueues];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(e[@"event"], @"$app_open", @"incorrect event name");
    
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"campaign_id"], @"the_campaign_id", @"campaign_id not equal");
}

- (void)testOptInWillAddOptInEvent
{
    stubTrack();
    stubEngage();
    [self.mixpanel optInTracking];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    [self waitForMixpanelQueues];
    if ([self.mixpanel.eventsQueue count] == 1) {
        NSDictionary *event = self.mixpanel.eventsQueue[0];
        XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
    }
    else {
        XCTAssertTrue([self.mixpanel.eventsQueue count] == 1, @"When opted in, event queue should have one even(opt in) being queued");
    }
}

- (void)testOptInTrackingForDistinctID
{
    stubTrack();
    stubEngage();
    [self.mixpanel optInTrackingForDistinctID:@"testDistinctId"];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    
    [self waitForMixpanelQueues];
    if ([self.mixpanel.eventsQueue count] == 1) {
        NSDictionary *event = self.mixpanel.eventsQueue[0];
        XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
    }
    else {
        XCTAssertTrue([self.mixpanel.eventsQueue count] == 1, @"When opted in, event queue should have one even(opt in) being queued");
    }
    
    XCTAssertEqualObjects(self.mixpanel.distinctId, @"testDistinctId", @"mixpanel identify failed to set distinct id");
    XCTAssertEqualObjects(self.mixpanel.people.distinctId, @"testDistinctId", @"mixpanel identify failed to set people distinct id");
    XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"identify: should move records from unidentified queue");
}

- (void)testOptInTrackingForDistinctIDAndWithEventProperties
{
    stubTrack();
    stubEngage();
    NSDate *now = [NSDate date];
    NSDictionary *p = @{ @"string": @"yello",
                         @"number": @3,
                         @"date": now,
                         @"$app_version": @"override" };
    [self.mixpanel optInTrackingForDistinctID:@"testDistinctId" withEventProperties:p];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"The current user should have opted in tracking");
    
    [self waitForMixpanelQueues];
    NSDictionary *props = self.mixpanel.eventsQueue.lastObject[@"properties"];
    XCTAssertEqualObjects(props[@"string"], @"yello");
    XCTAssertEqualObjects(props[@"number"], @3);
    XCTAssertEqualObjects(props[@"date"], now);
    XCTAssertEqualObjects(props[@"$app_version"], @"override", @"reserved property override failed");
    
    if ([self.mixpanel.eventsQueue count] == 1) {
        NSDictionary *event = self.mixpanel.eventsQueue[0];
        XCTAssertEqualObjects(event[@"event"], @"$opt_in", @"When opted in, a track '$opt_in' should have been queued");
    }
    else {
        XCTAssertTrue([self.mixpanel.eventsQueue count] == 1, @"When opted in, event queue should have one even(opt in) being queued");
    }
    
    XCTAssertEqualObjects(self.mixpanel.distinctId, @"testDistinctId", @"mixpanel identify failed to set distinct id");
    XCTAssertEqualObjects(self.mixpanel.people.distinctId, @"testDistinctId", @"mixpanel identify failed to set people distinct id");
    XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"identify: should move records from unidentified queue");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances
{
    stubTrack();
    stubEngage();
    Mixpanel *mixpanel1 = [Mixpanel sharedInstanceWithToken:[self randomTokenId] optOutTrackingByDefault:YES];
    XCTAssertTrue([mixpanel1 hasOptedOutTracking], @"When initialize with opted out flag set to YES, the current user should have opted out tracking");
    
    Mixpanel *mixpanel2 = [Mixpanel sharedInstanceWithToken:[self randomTokenId] optOutTrackingByDefault:NO];
    XCTAssertFalse([mixpanel2 hasOptedOutTracking], @"When initialize with opted out flag set to NO, the current user should have opted in tracking");
    
    [super deleteOptOutSettingsWithMixpanelInstance:mixpanel1];
    [super deleteOptOutSettingsWithMixpanelInstance:mixpanel2];
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO
{
    stubTrack();
    stubEngage();
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId] optOutTrackingByDefault:NO];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"When initialize with opted out flag set to NO, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyByDefault
{
    stubTrack();
    stubEngage();
    self.mixpanel = [Mixpanel sharedInstanceWithToken:[self randomTokenId]];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"By default, the current user should not opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptOut
{
    stubTrack();
    stubEngage();
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted out tracking");
}

- (void)testHasOptOutTrackingFlagBeingSetProperlyForOptIn
{
    stubTrack();
    stubEngage();
    [self.mixpanel optOutTracking];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking], @"By calling optOutTracking, the current user should have opted out tracking");
    [self.mixpanel optInTracking];
    XCTAssertFalse([self.mixpanel hasOptedOutTracking], @"When optOutTracking is called, the current user should have opted in tracking");
}

- (void)testOptOutTrackingWillNotGenerateEventQueue
{
    stubTrack();
    stubEngage();
    [self.mixpanel optOutTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"When opted out, events should not be queued");
}

- (void)testOptOutTrackingWillNotGeneratePeopleQueue
{
    stubTrack();
    stubEngage();
    [self.mixpanel identify:@"d1"];
    [self.mixpanel optOutTracking];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 0, @"When opted out, people should not be queued");
}

- (void)testOptOutTrackingWillSkipIdentify
{
    stubTrack();
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
    stubTrack();
    stubEngage();
    [self.mixpanel optOutTracking];
    [self.mixpanel createAlias:@"testAlias" forDistinctID:@"aDistinctID"];
    XCTAssertFalse([self.mixpanel.alias isEqualToString:@"testAlias"], @"When opted out, alias should not be set");
}

- (void)testOptOutTrackingRegisterSuperProperties {
    stubTrack();
    stubEngage();
    NSDictionary *p = @{ @"p1": @"a", @"p2": @3, @"p3": [NSDate date] };
    [self.mixpanel optOutTracking];
    [self.mixpanel registerSuperProperties:p];
    [self waitForMixpanelQueues];
    XCTAssertNotEqualObjects([self.mixpanel currentSuperProperties], p, @"When opted out, register super properties should not be successful");
}

- (void)testOptOutTrackingRegisterSuperPropertiesOnce {
    stubTrack();
    stubEngage();
    NSDictionary *p = @{ @"p4": @"a" };
    [self.mixpanel optOutTracking];
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForMixpanelQueues];
    XCTAssertNotEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                          @"When opted out, register super properties once should not be successful");
}

- (void)testOptOutWilSkipTimeEvent {
    stubTrack();
    stubEngage();
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
    stubEngage();
    [self.mixpanel optInTracking];
    [self.mixpanel identify:@"d1"];
    
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    //There will be an additional event for '$opt_in'
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 51, @"When opted in, events should have been queued");
    NSDictionary *e = self.mixpanel.eventsQueue.firstObject;
    XCTAssertEqualObjects(e[@"event"], @"$opt_in", @"incorrect optin event name");
    
    [self.mixpanel optOutTracking];
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"When opted out, events should have been purged");
}

- (void)testOptOutTrackingWillPurgePeopleQueue
{
    stubTrack();
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
    stubTrack();
    stubEngage();
    [self.mixpanel optInTracking];
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 50, @"When opted in, people queue should have been queued");
    
    NSMutableArray *peopleQueue = [NSMutableArray arrayWithArray:self.mixpanel.peopleQueue];
    [self.mixpanel optOutTracking];
    
    //In order to test if flush will be skipped, we have to re-create a fake peopleQueue since optOutTracking will clear peopleQueue.
    [self waitForMixpanelQueues];
    self.mixpanel.peopleQueue = [NSMutableArray arrayWithArray:peopleQueue];

    [self.mixpanel flush];
    [self waitForMixpanelQueues];
    
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 50, @"When opted out, people queue should not be flushed");
}

- (void)testOptOutWillSkipFlushEvent
{
    stubTrack();
    stubEngage();
    [self.mixpanel optInTracking];
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i = 0, n = 50; i < n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 51, @"When opted in, events should have been queued");
    
    NSMutableArray *eventsQueue = [NSMutableArray arrayWithArray:self.mixpanel.eventsQueue];
    [self.mixpanel optOutTracking];
   
    //In order to test if flush will be skipped, we have to create a fake eventsQueue since optOutTracking will clear eventsQueue.
    [self waitForMixpanelQueues];
    self.mixpanel.eventsQueue = [NSMutableArray arrayWithArray:eventsQueue];
    
    [self.mixpanel flush];
    [self waitForMixpanelQueues];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 51, @"When opted out, events should not be flushed");
}

@end
