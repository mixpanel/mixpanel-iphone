//
//  HelloMixpanelTests.m
//  Mixpanel
//
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "TestConstants.h"
#import "MixpanelPrivate.h"
#import "MixpanelPeoplePrivate.h"
#import "MixpanelGroup.h"
#import "MixpanelGroupPrivate.h"
#import "MPNetworkPrivate.h"
#import "MPDB.h"
#define DEVICE_PREFIX @"$device:"

@interface HelloMixpanelTests : MixpanelBaseTests

@end

@implementation HelloMixpanelTests

#pragma mark - Network
- (void)test5XXResponse {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel setServerURL:kFakeServerUrl];
    [testMixpanel track:@"Fake Event"];

    [testMixpanel flush];
    [self waitForMixpanelQueues:testMixpanel];
    
    [testMixpanel flush];
    [self waitForMixpanelQueues:testMixpanel];

    // Failure count should be 3
    NSTimeInterval waitTime = testMixpanel.network.requestsDisabledUntilTime - [[NSDate date] timeIntervalSince1970];
    NSLog(@"Delta wait time is %.3f", waitTime);
    XCTAssert(waitTime >= 110.f, "Network backoff time is less than 2 minutes.");
    XCTAssert(testMixpanel.network.consecutiveFailures == 2, @"Network failures did not equal 2");
    XCTAssert([self eventQueue:testMixpanel.apiToken].count == 1, @"Removed an event from the queue that was not sent");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testFlushEvents {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [testMixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"events should have been flushed");

    for (NSUInteger i=0, n=60; i<n; i++) {
        [testMixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"events should have been flushed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testFlushPeople {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [testMixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([[self peopleQueue:testMixpanel.apiToken] count] == 0, @"people should have been flushed");

    for (NSUInteger i=0, n=60; i<n; i++) {
        [testMixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }

    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0, @"people should have been flushed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testFlushNetworkFailure {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:NO andFlushInterval:60];
    [testMixpanel setServerURL:kFakeServerUrl];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [testMixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 50U, @"50 events should be queued up");

    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 50U, @"events should still be in the queue if flush fails");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testIdentify {
    for (NSInteger i = 0; i < 2; i++) { // run this twice to test reset works correctly wrt to distinct ids
        NSString *testToken = [self randomTokenId];
        Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:NO andFlushInterval:60];
        NSString *distinctId = @"d1";
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
        XCTAssertEqualObjects(testMixpanel.distinctId, [DEVICE_PREFIX stringByAppendingString:testMixpanel.defaultDeviceId], @"mixpanel identify failed to set default distinct id");
        XCTAssertEqualObjects(testMixpanel.anonymousId, testMixpanel.defaultDeviceId, @"mixpanel identify failed to set anonymous id");
#endif
        XCTAssertNil(testMixpanel.people.distinctId, @"mixpanel people distinct id should default to nil");
        XCTAssertNil(testMixpanel.userId, @"mixpanel userId should default to nil");

        [testMixpanel track:@"e1"];
        [self waitForMixpanelQueues:testMixpanel];
        XCTAssertEqual([self eventQueue:testMixpanel.apiToken].count, 1, @"events should be sent right away with default distinct id");
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
        XCTAssertEqualObjects(testMixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"], [DEVICE_PREFIX stringByAppendingString:testMixpanel.defaultDeviceId], @"events should use default distinct id if none set");
#endif
        [testMixpanel.people set:@"p1" to:@"a"];
        [self waitForMixpanelQueues:testMixpanel];
        XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0, @"people records should go to unidentified queue before identify:");
        XCTAssertTrue([self unIdentifiedPeopleQueue:testMixpanel.apiToken].count == 1, @"unidentified people records not queued");
        XCTAssertEqualObjects([self unIdentifiedPeopleQueue:testMixpanel.apiToken].lastObject[@"$token"], testToken, @"incorrect project token in people record");

        NSString *anonymousId = testMixpanel.anonymousId;
        [testMixpanel identify:distinctId];
        [self waitForMixpanelQueues:testMixpanel];
        XCTAssertEqualObjects(testMixpanel.anonymousId, anonymousId, @"mixpanel identify shouldn't change anonymousId");
        XCTAssertEqualObjects(testMixpanel.distinctId, distinctId, @"mixpanel identify failed to set distinct id");
        XCTAssertEqualObjects(testMixpanel.userId, distinctId, @"mixpanel identify failed to set user id");
        XCTAssertEqualObjects(testMixpanel.people.distinctId, distinctId, @"mixpanel identify failed to set people distinct id");
        XCTAssertTrue([self unIdentifiedPeopleQueue:testMixpanel.apiToken].count == 0, @"identify: should move records from unidentified queue");
        XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 1, @"identify: should move records to main people queue");
        XCTAssertEqualObjects([self peopleQueue:testMixpanel.apiToken].lastObject[@"$token"], testToken, @"incorrect project token in people record");
        XCTAssertEqualObjects([self peopleQueue:testMixpanel.apiToken].lastObject[@"$distinct_id"], distinctId, @"distinct id not set properly on unidentified people record");

        NSDictionary *p = [self peopleQueue:testMixpanel.apiToken].lastObject[@"$set"];
        XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");

        [self assertDefaultPeopleProperties:p];
        [testMixpanel.people set:@"p1" to:@"a"];
        [self waitForMixpanelQueues:testMixpanel];
        NSArray *unIdentifiedPeopleQueue = [self unIdentifiedPeopleQueue:testMixpanel.apiToken];
        NSArray *peopleQueue = [self peopleQueue:testMixpanel.apiToken];
        XCTAssertTrue(unIdentifiedPeopleQueue.count == 0, @"once idenitfy: is called, unidentified queue should be skipped");
        XCTAssertTrue(peopleQueue.count == 2, @"once identify: is called, records should go straight to main queue");

        [testMixpanel track:@"e2"];
        [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([self eventQueue:testMixpanel.apiToken].lastObject[@"properties"][@"distinct_id"], distinctId, @"events should use new distinct id after identify:");

        [testMixpanel reset];
        [self waitForMixpanelQueues:testMixpanel];
        [self removeDBfile:testMixpanel.apiToken];
    }
}

- (void)testIdentifyTrack {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSString *distinctIdBeforeidentify = testMixpanel.distinctId;

    testMixpanel.anonymousId = nil;
    testMixpanel.userId = nil;
    testMixpanel.hadPersistedDistinctId = false;

    [testMixpanel archive];

    NSString *distinctId = @"testIdentifyTrack";

    [testMixpanel identify:distinctId];
    [testMixpanel identify:distinctId]; // should not track $identify
    [self waitForMixpanelQueues:testMixpanel];
    [self waitForMixpanelQueues:testMixpanel];

    NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(e[@"event"], @"$identify", @"incorrect event name $identify");
    XCTAssertEqualObjects(p[@"distinct_id"], distinctId, @"incorrect distinct_id");
    XCTAssertEqualObjects(p[@"$anon_distinct_id"], distinctIdBeforeidentify, @"incorrect $anon_distinct_id");
    [testMixpanel reset];
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testIdentifyResetTrack {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];

    testMixpanel.anonymousId = nil;
    testMixpanel.userId = nil;
    testMixpanel.hadPersistedDistinctId = false;

    [testMixpanel archive];

    NSString *distinctId = @"testIdentifyTrack";
    NSString *originalDistinctId = testMixpanel.distinctId;
    [testMixpanel reset];
    [self waitForMixpanelQueues:testMixpanel];
    for (int i = 0; i < 3; i++) {
        NSString *prevDistinctId = testMixpanel.distinctId;
        NSMutableString *newDistinctId = [NSMutableString stringWithString:distinctId];
        [newDistinctId appendString:[@(i) stringValue]];
        [testMixpanel identify:newDistinctId];
        [self waitForMixpanelQueues:testMixpanel];
        [self waitForMixpanelQueues:testMixpanel];
        NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
        NSDictionary *p = e[@"properties"];
        XCTAssertEqualObjects(p[@"distinct_id"], newDistinctId, @"incorrect distinct_id");
        XCTAssertEqualObjects(p[@"$anon_distinct_id"], prevDistinctId, @"incorrect $anon_distinct_id");
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
        XCTAssertEqualObjects(prevDistinctId, originalDistinctId, @"After reset, IFV will be used - always the same");
#else
        XCTAssertNotEqual(prevDistinctId, originalDistinctId, @"After reset, UUID will be used - never the same");
#endif
        [testMixpanel reset];
        [self waitForMixpanelQueues:testMixpanel];
    }
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testUseUniqueDistinctI {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    Mixpanel *testMixpanel2 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    XCTAssertNotEqualObjects(testMixpanel.distinctId, testMixpanel2.distinctId, "by default, distinctId should not be unique to the device");
    
    Mixpanel *testMixpanel3 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES flushInterval:60 trackCrashes:NO useUniqueDistinctId:NO];
    Mixpanel *testMixpanel4 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES flushInterval:60 trackCrashes:NO useUniqueDistinctId:NO];
    XCTAssertNotEqualObjects(testMixpanel3.distinctId, testMixpanel4.distinctId, "distinctId should not be unique to the device if useUniqueDistinctId is set to NO");
    
    Mixpanel *testMixpanel5 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES flushInterval:60 trackCrashes:NO useUniqueDistinctId:YES];
    Mixpanel *testMixpanel6 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES flushInterval:60 trackCrashes:NO useUniqueDistinctId:YES];
    XCTAssertEqualObjects(testMixpanel5.distinctId, testMixpanel6.distinctId, "distinctId should be unique to the device if useUniqueDistinctId is set to YES");
}

- (void)testHadPersistedDistinctId {
    NSString *randomTokenId = [self randomTokenId];
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:randomTokenId trackAutomaticEvents:YES andFlushInterval:60];
    NSString *distinctIdBeforeidentify = testMixpanel.distinctId;
    
    Mixpanel *testMixpanel2 = [[Mixpanel alloc] initWithToken:randomTokenId  trackAutomaticEvents:YES andFlushInterval:60];
    XCTAssertEqualObjects(testMixpanel2.distinctId, distinctIdBeforeidentify, @"mixpanel anonymous distinct id should not be changed for each init");

    NSString *distinctId = @"d1";

    [testMixpanel identify:distinctId];
    [testMixpanel track:@"Something Happened"];
    [self waitForMixpanelQueues:testMixpanel];

    XCTAssertEqualObjects([DEVICE_PREFIX stringByAppendingString:testMixpanel.anonymousId], distinctIdBeforeidentify, @"mixpanel identify shouldn't change anonymousId");
    XCTAssertEqualObjects(testMixpanel.distinctId, distinctId, @"mixpanel identify failed to set distinct id");
    XCTAssertEqualObjects(testMixpanel.userId, distinctId, @"mixpanel identify failed to set user id");
    XCTAssertEqualObjects(testMixpanel.people.distinctId, distinctId, @"mixpanel identify failed to set people distinct id");
    XCTAssertTrue(testMixpanel.hadPersistedDistinctId, @"mixpanel identify failed to set hadPersistedDistinctId flag as only distinctId existed before");

    NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"distinct_id"], distinctId, @"incorrect distinct_id");
    XCTAssertEqualObjects([DEVICE_PREFIX stringByAppendingString:p[@"$device_id"]], distinctIdBeforeidentify, @"incorrect device_id");
    XCTAssertEqualObjects(p[@"$user_id"], distinctId, @"incorrect user_id");
    XCTAssertTrue(p[@"$had_persisted_distinct_id"], @"incorrect flag");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testTrackWithDefaultProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel track:@"Something Happened"];
    [self waitForMixpanelQueues:testMixpanel];
    [self waitForAsyncQueue];
    NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
    XCTAssertEqualObjects(e[@"event"], @"Something Happened", @"incorrect event name");

    NSDictionary *p = e[@"properties"];
    XCTAssertNotNil(p[@"$app_version"], @"$app_version not set");
    XCTAssertNotNil(p[@"$app_release"], @"$app_release not set");
    XCTAssertNotNil(p[@"$lib_version"], @"$lib_version not set");
    XCTAssertNotNil(p[@"$model"], @"$model not set");
    XCTAssertNotNil(p[@"$os"], @"$os not set");
    XCTAssertNotNil(p[@"$os_version"], @"$os_version not set");
    XCTAssertNotNil(p[@"$screen_height"], @"$screen_height not set");
    XCTAssertNotNil(p[@"$screen_width"], @"$screen_width not set");
    XCTAssertNotNil(p[@"distinct_id"], @"distinct_id not set");
    XCTAssertNotNil(p[@"mp_device_model"], @"mp_device_model not set");
    XCTAssertNotNil(p[@"time"], @"time not set");

    XCTAssertEqualObjects(p[@"$manufacturer"], @"Apple", @"incorrect $manufacturer");
    XCTAssertEqualObjects(p[@"mp_lib"], @"iphone", @"incorrect mp_lib");
    XCTAssertEqualObjects(p[@"token"], testMixpanel.apiToken, @"incorrect token");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testTrackWithCustomProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDate *now = [NSDate date];
    NSDictionary *p = @{ @"string": @"yello",
                         @"number": @3,
                         @"date": now,
                         @"$app_version": @"override" };
    [testMixpanel track:@"Something Happened" properties:p];
    [self waitForMixpanelQueues:testMixpanel];

    NSDictionary *props = [self eventQueue:testMixpanel.apiToken].lastObject[@"properties"];
    XCTAssertEqualObjects(props[@"string"], @"yello");
    XCTAssertEqualObjects(props[@"number"], @3);
    XCTAssertTrue([self isDateString:props[@"date"] equalToDate:now]);
    XCTAssertEqualObjects(props[@"$app_version"], @"override", @"reserved property override failed");
}

- (void)testTrackWithCustomDistinctIdAndToken {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = @{ @"token": @"t1", @"distinct_id": @"d1" };
    [testMixpanel track:@"e1" properties:p];
    [self waitForMixpanelQueues:testMixpanel];

    NSString *trackToken = [self eventQueue:testMixpanel.apiToken].lastObject[@"properties"][@"token"];
    NSString *trackDistinctId = [self eventQueue:testMixpanel.apiToken].lastObject[@"properties"][@"distinct_id"];
    XCTAssertEqualObjects(trackToken, @"t1", @"user-defined distinct id not used in track.");
    XCTAssertEqualObjects(trackDistinctId, @"d1", @"user-defined distinct id not used in track.");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testRegisterSuperProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = @{ @"p1": @"a", @"p2": [NSDate date]};
    [testMixpanel registerSuperProperties:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties], p, @"register super properties failed");

    p = @{ @"p1": @"b" };
    [testMixpanel registerSuperProperties:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties][@"p1"], @"b",
                         @"register super properties failed to overwrite existing value");

    p = @{ @"p4": @"a" };
    [testMixpanel registerSuperPropertiesOnce:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed first time");

    p = @{ @"p4": @"b" };
    [testMixpanel registerSuperPropertiesOnce:p];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed second time");

    p = @{ @"p4": @"c" };
    [testMixpanel registerSuperPropertiesOnce:p defaultValue:@"d"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once with default value failed when no match");

    [testMixpanel registerSuperPropertiesOnce:p defaultValue:@"a"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects([testMixpanel currentSuperProperties][@"p4"], @"c",
                         @"register super properties once with default value failed when match");

    [testMixpanel unregisterSuperProperty:@"a"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertNil([testMixpanel currentSuperProperties][@"a"], @"unregister super property failed");
    XCTAssertNoThrow([testMixpanel unregisterSuperProperty:@"a"],
                     @"unregister non-existent super property should not throw");

    [testMixpanel clearSuperProperties];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([[testMixpanel currentSuperProperties] count] == 0, @"clear super properties failed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testInvalidPropertiesTrack {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = @{ @"data": [NSData data] };
    XCTAssertThrows([testMixpanel track:@"e1" properties:p], @"property type should not be allowed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testInvalidSuperProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = @{ @"data": [NSData data] };
    XCTAssertThrows([testMixpanel registerSuperProperties:p], @"property type should not be allowed");
    XCTAssertThrows([testMixpanel registerSuperPropertiesOnce:p], @"property type should not be allowed");
    XCTAssertThrows([testMixpanel registerSuperPropertiesOnce:p defaultValue:@"v"], @"property type should not be allowed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testValidPropertiesTrack {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = [self allPropertyTypes];
    XCTAssertNoThrow([testMixpanel track:@"e1" properties:p], @"property type should be allowed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testValidSuperProperties {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = [self allPropertyTypes];
    XCTAssertNoThrow([testMixpanel registerSuperProperties:p], @"property type should be allowed");
    XCTAssertNoThrow([testMixpanel registerSuperPropertiesOnce:p],  @"property type should be allowed");
    XCTAssertNoThrow([testMixpanel registerSuperPropertiesOnce:p defaultValue:@"v"],  @"property type should be allowed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testReset {
    NSString *testToken = [self randomTokenId];
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel identify:@"d1"];
    [testMixpanel track:@"e1"];

    NSDictionary *p = @{ @"p1": @"a" };
    [testMixpanel registerSuperProperties:p];
    [testMixpanel.people set:p];

    [testMixpanel archive];
    [testMixpanel reset];
    [self waitForMixpanelQueues:testMixpanel];
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
    NSString *defaultDeviceId = [testMixpanel defaultDeviceId];
    XCTAssertEqualObjects(testMixpanel.distinctId, [DEVICE_PREFIX stringByAppendingString:defaultDeviceId], @"distinct id failed to reset");
#endif
    XCTAssertNil(testMixpanel.people.distinctId, @"people distinct id failed to reset");
    XCTAssertTrue([testMixpanel currentSuperProperties].count == 0, @"super properties failed to reset");
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"events queue failed to reset");
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0, @"people queue failed to reset");

    testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    [self waitForMixpanelQueues:testMixpanel];
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
    NSString *defaultDeviceId = [testMixpanel defaultDeviceId];
    XCTAssertEqualObjects(testMixpanel.distinctId, [DEVICE_PREFIX stringByAppendingString:defaultDeviceId], @"distinct id failed to reset after archive");
#endif
    XCTAssertNil(testMixpanel.people.distinctId, @"people distinct id failed to reset after archive");
    XCTAssertTrue([testMixpanel currentSuperProperties].count == 0, @"super properties failed to reset after archive");
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"events queue failed to reset after archive");
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0, @"people queue failed to reset after archive");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testArchive {
    NSString *testToken = [self randomTokenId];
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.serverURL = kFakeServerUrl;
    [testMixpanel archive];
    testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
    NSString *defaultDeviceId = [testMixpanel defaultDeviceId];
    XCTAssertEqualObjects(testMixpanel.distinctId, [DEVICE_PREFIX stringByAppendingString:defaultDeviceId], @"default distinct id archive failed");
#endif
    XCTAssertTrue([[testMixpanel currentSuperProperties] count] == 0, @"default super properties archive failed");
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"default events queue archive failed");
    XCTAssertNil(testMixpanel.people.distinctId, @"default people distinct id archive failed");
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 0, @"default people queue archive failed");
    XCTAssertTrue([self groupQueue:testMixpanel.apiToken].count == 0, @"default groups queue archive failed");

    NSDictionary *p = @{@"p1": @"a"};
    [testMixpanel identify:@"d1"];
    [testMixpanel registerSuperProperties:p];
    [testMixpanel track:@"e1"];
    [testMixpanel.people set:p];
    MixpanelGroup *g = [testMixpanel getGroup:@"group" groupID:@"id1"];
    NSDictionary *props = @{@"key":@"value"};
    [g set:props];
    testMixpanel.timedEvents[@"e2"] = @5.0;
    [self waitForMixpanelQueues:testMixpanel];

    [testMixpanel archive];
    testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.serverURL = kFakeServerUrl;
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqualObjects(testMixpanel.distinctId, @"d1", @"custom distinct archive failed");
   
    XCTAssertTrue([[testMixpanel currentSuperProperties] count] == 1, @"custom super properties archive failed");
    NSArray *eventQueue = [self eventQueue:testMixpanel.apiToken];
    NSArray *peopleQueue = [self peopleQueue:testMixpanel.apiToken];
    NSArray *groupQueue = [self groupQueue:testMixpanel.apiToken];
    
    XCTAssertTrue(eventQueue.count == 2, @"event was not successfully archived/unarchived");
    XCTAssertEqualObjects(groupQueue.lastObject[@"$set"], props, @"group update was not successfully archived/unarchived");
    XCTAssertEqualObjects(testMixpanel.people.distinctId, @"d1", @"custom people distinct id archive failed");
    XCTAssertTrue(peopleQueue.count == 1, @"pending people queue archive failed");
    XCTAssertTrue(groupQueue.count == 1, @"pending groups queue archive failed");
    XCTAssertEqualObjects(testMixpanel.timedEvents[@"e2"], @5.0, @"timedEvents archive failed");

    testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.serverURL = kFakeServerUrl;
    eventQueue = [self eventQueue:testMixpanel.apiToken];
    peopleQueue = [self peopleQueue:testMixpanel.apiToken];
    groupQueue = [self groupQueue:testMixpanel.apiToken];
    XCTAssertEqualObjects(testMixpanel.distinctId, @"d1", @"expecting d1 as distinct id as initialised");
    XCTAssertTrue([[testMixpanel currentSuperProperties] count] == 1, @"default super properties expected to have 1 item");
    XCTAssertNotNil(eventQueue, @"default events queue from no file is nil");
    XCTAssertTrue(eventQueue.count == 2, @"default events queue expecting 2 items ($identify call added)");
    XCTAssertNotNil(testMixpanel.people.distinctId, @"default people distinct id from no file failed");
    XCTAssertNotNil(peopleQueue, @"default people queue from no file is nil");
    XCTAssertTrue(peopleQueue.count == 1, @"default people queue expecting 1 item");
    XCTAssertNotNil(groupQueue, @"default groups queue from no file is nil");
    XCTAssertTrue(groupQueue.count == 1, @"default groups queue expecting 1 item");
    XCTAssertTrue(testMixpanel.timedEvents.count == 1, @"timedEvents expecting 1 item");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testArchiveInMultithreadNotCrash {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSDictionary *p = @{@"p1": @"a"};
    [testMixpanel identify:@"d1"];
    [testMixpanel registerSuperProperties:p];
    [testMixpanel track:@"e1"];
    [testMixpanel.people set:p];
    [self waitForMixpanelQueues:testMixpanel];

    __block NSMutableDictionary *properties = [NSMutableDictionary new];
    properties[@"key"] = @"value";

    for (int i = 0; i < 100; i++) {
        dispatch_async(testMixpanel.serialQueue, ^{
            [testMixpanel track:@"test" properties:properties];
        });
    }

    for (int i = 0; i < 100; i++) {
        [testMixpanel track:@"test" properties:properties];
        dispatch_async(testMixpanel.serialQueue, ^{
            [testMixpanel archive];
        });
    }

    [self waitForMixpanelQueues:testMixpanel];
    Mixpanel *testMixpanel1 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES  andFlushInterval:60];
    XCTAssertTrue([self eventQueue:testMixpanel1.apiToken].count >= 0, @"archive should not crash");
    [self removeDBfile:testMixpanel1.apiToken];
}

- (void)testMixpanelDelegate {
    NSString *testToken = [self randomTokenId];
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    self.mixpanelWillFlush = NO;
    testMixpanel.delegate = self;

    [testMixpanel identify:@"testMixpanelDelegate"];
    [testMixpanel track:@"e1"];
    [testMixpanel.people set:@"p1" to:@"a"];
    [testMixpanel flush];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count >= 1, @"delegate should have stopped flush");
    XCTAssertTrue([self peopleQueue:testMixpanel.apiToken].count == 1, @"delegate should have stopped flush");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testNilArguments {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSString *originalDistinctID = testMixpanel.distinctId;
    [testMixpanel identify:nil];
    XCTAssertEqualObjects(testMixpanel.distinctId, originalDistinctID, @"identify nil should do nothing.");

    [testMixpanel track:nil];
    [testMixpanel track:nil properties:nil];
    [testMixpanel registerSuperProperties:nil];
    [testMixpanel registerSuperPropertiesOnce:nil];
    [testMixpanel registerSuperPropertiesOnce:nil defaultValue:nil];
    [self waitForMixpanelQueues:testMixpanel];
    // legacy behavior
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 2, @"track with nil should create mp_event event");
    XCTAssertEqualObjects([self eventQueue:testMixpanel.apiToken].lastObject[@"event"], @"mp_event", @"track with nil should create mp_event event");
    XCTAssertNotNil([testMixpanel currentSuperProperties], @"setting super properties to nil should have no effect");
    XCTAssertTrue([[testMixpanel currentSuperProperties] count] == 0, @"setting super properties to nil should have no effect");

    XCTAssertThrows([testMixpanel.people set:nil], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people set:nil to:@"a"], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people set:@"p1" to:nil], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people set:nil to:nil], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people increment:nil], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people increment:nil by:@3], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people increment:@"p1" by:nil], @"should not take nil argument");
    XCTAssertThrows([testMixpanel.people increment:nil by:nil], @"should not take nil argument");
    [self removeDBfile:testMixpanel.apiToken];
#pragma clang diagnostic pop
}

- (void)testEventTiming {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    [testMixpanel track:@"Something Happened"];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *e = [self eventQueue:testMixpanel.apiToken].lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"New events should not be timed.");

    [testMixpanel timeEvent:@"400 Meters"];

    [testMixpanel track:@"500 Meters"];
    [self waitForMixpanelQueues:testMixpanel];
    e = [self eventQueue:testMixpanel.apiToken].lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"The exact same event name is required for timing.");

    [testMixpanel track:@"400 Meters"];
    [self waitForMixpanelQueues:testMixpanel];
    e = [self eventQueue:testMixpanel.apiToken].lastObject;
    p = e[@"properties"];
    XCTAssertNotNil(p[@"$duration"], @"This event should be timed.");

    [testMixpanel track:@"400 Meters"];
    [self waitForMixpanelQueues:testMixpanel];
    e = [self eventQueue:testMixpanel.apiToken].lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"Tracking the same event should require a second call to timeEvent.");

    [testMixpanel timeEvent:@"Time Event A"];
    [testMixpanel timeEvent:@"Time Event B"];
    [testMixpanel timeEvent:@"Time Event C"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue(testMixpanel.timedEvents.count == 3, @"Each call to timeEvent: should add an event to timedEvents");
    XCTAssertNotNil(testMixpanel.timedEvents[@"Time Event A"], @"Keys in timedEvents should be event names");
    [testMixpanel clearTimedEvent:@"Time Event A"];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertNil(testMixpanel.timedEvents[@"Time Event A"], @"clearTimedEvent: should remove key/value pair");
    [testMixpanel clearTimedEvents];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertTrue(testMixpanel.timedEvents.count == 0, @"clearTimedEvents should remove all key/value pairs");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testNetworkingWithStress {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    self.mixpanelWillFlush = NO;
    for (NSInteger i = 1; i <= 500; i++) {
        [testMixpanel track:@"Track Call"];
    }
    [testMixpanel setServerURL:kFakeServerUrl];
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 500, @"none supposed to be flushed");
    testMixpanel.network.requestsDisabledUntilTime = 0;
    [testMixpanel setServerURL:kDefaultServerString];
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"supposed to all be flushed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testConcurrentTracking {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];

    self.mixpanelWillFlush = NO;
    [testMixpanel setServerURL:kFakeServerUrl];
    dispatch_queue_t concurrentQueue = dispatch_queue_create("test_concurrent_queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t trackGroup = dispatch_group_create();
    for (int i = 0; i < 500; i++) {
        dispatch_group_async(trackGroup, concurrentQueue, ^{
            [testMixpanel track:[NSString stringWithFormat:@"%d", i]];
        });
    }
    dispatch_group_wait(trackGroup, DISPATCH_TIME_FOREVER);
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    for (int i = 0; i < 500; i++) {
        BOOL found = NO;
        for (NSDictionary *event in [self eventQueue:testMixpanel.apiToken]) {
            if ([event[@"event"] intValue] == i) {
                found = YES;
                break;
            }
        }
        XCTAssertTrue(found, @"event that was tracked not found in eventsQueue");
    }
    [testMixpanel setServerURL:kDefaultServerString];
    testMixpanel.network.requestsDisabledUntilTime = 0;
    [self flushAndWaitForMixpanelQueues:testMixpanel];
    XCTAssertTrue([self eventQueue:testMixpanel.apiToken].count == 0, @"supposed to all be flushed");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testInitializeMixpanelOnBackgroundThread {
    XCTestExpectation *expectation = [self expectationWithDescription:@"main thread checker found no errors"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
        XCTAssertNotNil(testMixpanel);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testMPDB {
    NSUInteger randomId = arc4random();
    NSString *testToken = [NSString stringWithFormat:@"%lu", (unsigned long)randomId];
    int numRows = 50;
    int halfRows = numRows/2;
    NSString *eventName = @"Test Event";
    [self removeDBfile:testToken];
    MPDB *mpdb = [[MPDB alloc] initWithToken:testToken];
    [mpdb open];
    for (NSString *pType in @[@"events", @"people", @"groups"]) {
        NSArray *emptyArray = [mpdb readRows:pType numRows:numRows flag:false];
        XCTAssertTrue(emptyArray.count == 0, "Table should be empty");
        for (int i = 0; i < numRows; i++) {
            NSDictionary *eventObj = @{@"event": eventName, @"properties": @{@"index": @(i)}};
            NSData *eventData = [NSJSONSerialization dataWithJSONObject:eventObj options:0 error:NULL];
            [mpdb insertRow:pType data:eventData flag:false];
            NSLog(@"%d", i);
        }
        NSArray *dataArray = [mpdb readRows:pType numRows:numRows flag:halfRows];
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        NSUInteger index = 0;
        for (NSDictionary *entity in dataArray) {
            [ids addObject:entity[@"id"]];
            XCTAssertEqual(entity[@"event"], eventName, "Event name should be unchanged");
            // index should be oldest events, 0 - 24
            XCTAssertEqual(entity[@"properties"], @{@"index": @(index)}, "Should read oldest events first");
            index++;
        }

        [mpdb deleteRows:pType ids:@[@1, @2, @3] isDeleteAll:NO];
        NSArray *dataArray2 = [mpdb readRows:pType numRows:numRows flag:false];
        // even though we request numRows, there should only be numRows - 3 left
        XCTAssertEqual([dataArray2 count], 47);
        NSUInteger index2 = 0;
        for (NSDictionary *entity in dataArray2) {
            XCTAssertEqualObjects(entity[@"event"], eventName, "Event name should be unchanged");
            // oldest events (0-2) should have been deleted so index should be more recent events 3-49
            NSNumber *idx = entity[@"properties"][@"index"];
            XCTAssertEqualObjects(idx, @(index2 + 3), "Should have deleted oldest events first");
            index2++;
        }
    }
    [mpdb close];
    // TODO: What's up with this log we get when deleting the db file? Connection should be closed and nil.
    // BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use
    [self removeDBfile:testToken];
}

- (void)testMigration
{
    NSString *testToken = @"testToken";
    [self removeDBfile:testToken];
    // copy the legacy archived file for the migration test
    NSArray *legacyFiles = @[@"mixpanel-testToken-events.plist", @"mixpanel-testToken-properties.plist", @"mixpanel-testToken-groups.plist", @"mixpanel-testToken-people.plist", @"mixpanel-testToken-optOut.plist"];
    [self prepareForMigrationFiles:legacyFiles];
    
    // initialize mixpanel will do the migration automatically if found legacy archive files.
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:testToken trackAutomaticEvents:YES andFlushInterval:60];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-events.plist"]], @"after migration, the legacy archive files should be removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-properties.plist"]], @"after migration, the legacy archive files should be removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-groups.plist"]], @"after migration, the legacy archive files should be removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-people.plist"]], @"after migration, the legacy archive files should be removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-optOut.plist"]], @"after migration, the legacy archive files should be removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[libraryDirectory stringByAppendingPathComponent:@"mixpanel-testToken-optOutStatus.plist"]], @"after migration, the legacy archive files should be removed");
    NSArray *events = [self eventQueue:testMixpanel.apiToken];
    XCTAssertEqual(events.count, 306);
    XCTAssertEqualObjects(events[0][@"event"], @"$identify");
    
    XCTAssertEqualObjects(events[1][@"event"], @"Logged in");
    XCTAssertEqualObjects(events[2][@"event"], @"$ae_first_open");
    XCTAssertEqualObjects(events[3][@"event"], @"Tracked event 1");
    NSDictionary *properties = events.lastObject[@"properties"];
    NSArray *coolProperty = (NSArray *)properties[@"Cool Property"];
    NSArray *coolPropertyValue = @[@12345,@301];
    XCTAssertEqualObjects(coolProperty, coolPropertyValue);
    XCTAssertEqualObjects(properties[@"Super Property 2"], @"p2");
    
    NSArray *peopleQueue = [self peopleQueue:testMixpanel.apiToken];
    XCTAssertEqual(peopleQueue.count, 6);
    XCTAssertEqualObjects(peopleQueue[0][@"$distinct_id"], @"demo_user");
    XCTAssertEqualObjects(peopleQueue[0][@"$token"], @"testToken");
    NSDictionary *appendProperties = peopleQueue[5][@"$append"];
    XCTAssertEqualObjects(appendProperties[@"d"], @"goodbye");
    
    NSArray *groupQueue = [self groupQueue:testMixpanel.apiToken];
    XCTAssertEqual(groupQueue.count, 2);
    XCTAssertEqualObjects(groupQueue[0][@"$group_key"], @"Cool Property");
    NSDictionary *setProperties = groupQueue[0][@"$set"];
    XCTAssertEqualObjects(setProperties[@"g"], @"yo");
    NSDictionary *setProperties2 = groupQueue[1][@"$set"];
    XCTAssertEqualObjects(setProperties2[@"a"], @1);
    XCTAssertTrue([MixpanelPersistence loadOptOutStatusFlagWithApiToken:testToken]);
    
    //timedEvents
    NSDictionary *testTimedEvents = [MixpanelPersistence loadTimedEvents:testToken];
    XCTAssertEqual(testTimedEvents.count, 3);
    XCTAssertNotNil(testTimedEvents[@"Time Event A"]);
    XCTAssertNotNil(testTimedEvents[@"Time Event B"]);
    XCTAssertNotNil(testTimedEvents[@"Time Event C"]);
    MixpanelIdentity *identity = [MixpanelPersistence loadIdentity:testToken];
    XCTAssertEqualObjects(identity.distinctId, @"demo_user");
    XCTAssertEqualObjects(identity.peopleDistinctId, @"demo_user");
    XCTAssertNotNil(identity.anonymousId);
    XCTAssertEqualObjects(identity.userId, @"demo_user");
    XCTAssertEqualObjects(identity.alias, @"New Alias");
    XCTAssertEqual(identity.hadPersistedDistinctId, false);
    
    NSDictionary *superProperties = [MixpanelPersistence loadSuperProperties:testToken];
    XCTAssertEqual(superProperties.count, 7);
    XCTAssertEqualObjects(superProperties[@"Super Property 1"], @1);
    [self removeDBfile:testToken];
}

- (void)prepareForMigrationFiles:(NSArray *)fileNames
{
    for (NSString *fileName in fileNames) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDirectory = [paths objectAtIndex:0];

        NSString *filePath = [libraryDirectory stringByAppendingPathComponent:fileName];

        if ([fileManager fileExistsAtPath:filePath] == NO) {
            NSString *resourcePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingString:[NSString stringWithFormat:@"/%@",fileName]];
            if(![fileManager copyItemAtPath:resourcePath toPath:filePath error:&error]) {
                NSLog(@"%@", [error localizedDescription]);
            }
        }
    }
}

@end
