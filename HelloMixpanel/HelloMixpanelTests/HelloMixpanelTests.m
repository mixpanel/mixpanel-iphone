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

@interface HelloMixpanelTests : MixpanelBaseTests

@end

@implementation HelloMixpanelTests

#pragma mark - Network
- (void)test5XXResponse {
    stubTrack().andReturn(503);
    
    [self.mixpanel track:@"Fake Event"];
    
    [self.mixpanel flush];
    [self waitForSerialQueue];
    
    [self.mixpanel flush];
    [self waitForSerialQueue];
    
    // Failure count should be 3
    NSTimeInterval waitTime = self.mixpanel.networkRequestsAllowedAfterTime - [[NSDate date] timeIntervalSince1970];
    NSLog(@"Delta wait time is %.3f", waitTime);
    XCTAssert(waitTime >= 120.f, "Network backoff time is less than 2 minutes.");
    XCTAssert(self.mixpanel.networkConsecutiveFailures == 2, @"Network failures did not equal 2");
    XCTAssert(self.mixpanel.eventsQueue.count == 1, @"Removed an event from the queue that was not sent");
}

- (void)testRetryAfterHTTPHeader {
    stubTrack().andReturn(200).withHeader(@"Retry-After", @"60");
    
    [self.mixpanel track:@"Fake Event"];
    
    [self.mixpanel flush];
    [self waitForSerialQueue];
    
    [self.mixpanel flush];
    [self waitForSerialQueue];
    
    // Failure count should be 3
    NSLog(@"Delta wait time is %.3f", self.mixpanel.networkRequestsAllowedAfterTime - [[NSDate date] timeIntervalSince1970]);
    NSTimeInterval deltaWaitTime = self.mixpanel.networkRequestsAllowedAfterTime - [[NSDate date] timeIntervalSince1970];
    XCTAssert(fabs(60 - deltaWaitTime) < 5, @"Mixpanel did not respect 'Retry-After' HTTP header");
    XCTAssert(self.mixpanel.networkConsecutiveFailures == 0, @"Network failures did not equal 0");
}

- (void)testFlushEvents {
    stubTrack();
    
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events should have been flushed");
    
    for (NSUInteger i=0, n=60; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events should have been flushed");
}

- (void)testFlushPeople {
    stubEngage();

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 0, @"people should have been flushed");
    
    for (NSUInteger i=0, n=60; i<n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 0, @"people should have been flushed");
}

- (void)testFlushNetworkFailure {
    stubTrack().andFailWithError([NSError errorWithDomain:@"com.mixpanel.sdk.testing" code:1 userInfo:nil]);

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50U, @"50 events should be queued up");
    
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50U, @"events should still be in the queue if flush fails");
}

- (void)testAddingEventsAfterFlush {
    stubTrack();
    
    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=10; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 10U, @"10 events should be queued up");
    
    [self.mixpanel flush];
    for (NSUInteger i=0, n=5; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 5U, @"5 more events should be queued up");
    
    [self flushAndWaitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"events should have been flushed");
}

- (void)testDropEvents {
    self.mixpanel.delegate = self;
    self.mixpanelWillFlush = NO;
    
    NSMutableArray *events = [NSMutableArray array];
    for (NSInteger i = 0; i < 5000; i++) {
        [events addObject:@{@"i": @(i)}];
    }
    self.mixpanel.eventsQueue = events;
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 5000);
    
    for (NSInteger i = 0; i < 5; i++) {
        [self.mixpanel track:@"event" properties:@{ @"i": @(5000 + i) }];
    }
    [self waitForSerialQueue];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 5000);
    XCTAssertEqualObjects(e[@"properties"][@"i"], @(5004));
}

- (void)testIdentify {
    for (NSInteger i = 0; i < 2; i++) { // run this twice to test reset works correctly wrt to distinct ids
        NSString *distinctId = @"d1";
        // try this for IFA, ODIN and nil
        XCTAssertEqualObjects(self.mixpanel.distinctId, self.mixpanel.defaultDistinctId, @"mixpanel identify failed to set default distinct id");
        XCTAssertNil(self.mixpanel.people.distinctId, @"mixpanel people distinct id should default to nil");
        
        [self.mixpanel track:@"e1"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"events should be sent right away with default distinct id");
        XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"], self.mixpanel.defaultDistinctId, @"events should use default distinct id if none set");
        
        [self.mixpanel.people set:@"p1" to:@"a"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people records should go to unidentified queue before identify:");
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 1, @"unidentified people records not queued");
        XCTAssertEqualObjects(self.mixpanel.people.unidentifiedQueue.lastObject[@"$token"], kTestToken, @"incorrect project token in people record");
        
        [self.mixpanel identify:distinctId];
        [self waitForSerialQueue];
        XCTAssertEqualObjects(self.mixpanel.distinctId, distinctId, @"mixpanel identify failed to set distinct id");
        XCTAssertEqualObjects(self.mixpanel.people.distinctId, distinctId, @"mixpanel identify failed to set people distinct id");
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"identify: should move records from unidentified queue");
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"identify: should move records to main people queue");
        XCTAssertEqualObjects(self.mixpanel.peopleQueue.lastObject[@"$token"], kTestToken, @"incorrect project token in people record");
        XCTAssertEqualObjects(self.mixpanel.peopleQueue.lastObject[@"$distinct_id"], distinctId, @"distinct id not set properly on unidentified people record");
        
        NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$set"];
        XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
        
        [self assertDefaultPeopleProperties:p];
        [self.mixpanel.people set:@"p1" to:@"a"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"once idenitfy: is called, unidentified queue should be skipped");
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 2, @"once identify: is called, records should go straight to main queue");
        
        [self.mixpanel track:@"e2"];
        [self waitForSerialQueue];
        XCTAssertEqual(self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"], distinctId, @"events should use new distinct id after identify:");
        
        [self.mixpanel reset];
        [self waitForSerialQueue];
    }
}

- (void)testTrackWithDefaultProperties {
    [self.mixpanel track:@"Something Happened"];
    [self waitForSerialQueue];
    
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
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
    XCTAssertEqualObjects(p[@"token"], kTestToken, @"incorrect token");
}

- (void)testTrackWithCustomProperties {
    NSDate *now = [NSDate date];
    NSDictionary *p = @{ @"string": @"yello",
                         @"number": @3,
                         @"date": now,
                         @"$app_version": @"override" };
    [self.mixpanel track:@"Something Happened" properties:p];
    [self waitForSerialQueue];
    
    NSDictionary *props = self.mixpanel.eventsQueue.lastObject[@"properties"];
    XCTAssertEqualObjects(props[@"string"], @"yello");
    XCTAssertEqualObjects(props[@"number"], @3);
    XCTAssertEqualObjects(props[@"date"], now);
    XCTAssertEqualObjects(props[@"$app_version"], @"override", @"reserved property override failed");
}

- (void)testDateEncodingFromJSON {
    NSDate *fixedDate = [NSDate dateWithTimeIntervalSince1970:1400000000];
    NSArray *a = @[ @{ @"event": @"an event", @"properties": @{ @"eventdate": fixedDate } } ];
    NSString *json = [[NSString alloc] initWithData:[self.mixpanel JSONSerializeObject:a]
                                           encoding:NSUTF8StringEncoding];
    XCTAssert([json rangeOfString:@"\"eventdate\":\"2014-05-13T16:53:20.000Z\""].location != NSNotFound);
}

- (void)testTrackWithCustomDistinctIdAndToken {
    NSDictionary *p = @{ @"token": @"t1", @"distinct_id": @"d1" };
    [self.mixpanel track:@"e1" properties:p];
    [self waitForSerialQueue];
    
    NSString *trackToken = self.mixpanel.eventsQueue.lastObject[@"properties"][@"token"];
    NSString *trackDistinctId = self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"];
    XCTAssertEqualObjects(trackToken, @"t1", @"user-defined distinct id not used in track.");
    XCTAssertEqualObjects(trackDistinctId, @"d1", @"user-defined distinct id not used in track.");
}

- (void)testRegisterSuperProperties {
    NSDictionary *p = @{ @"p1": @"a", @"p2": @3, @"p2": [NSDate date] };
    [self.mixpanel registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties], p, @"register super properties failed");
    
    p = @{ @"p1": @"b" };
    [self.mixpanel registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p1"], @"b",
                         @"register super properties failed to overwrite existing value");
    
    p = @{ @"p4": @"a" };
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed first time");
    
    p = @{ @"p4": @"b" };
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed second time");
    
    p = @{ @"p4": @"c" };
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"d"];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once with default value failed when no match");
    
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"a"];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"c",
                         @"register super properties once with default value failed when match");
    
    [self.mixpanel unregisterSuperProperty:@"a"];
    [self waitForSerialQueue];
    XCTAssertNil([self.mixpanel currentSuperProperties][@"a"], @"unregister super property failed");
    XCTAssertNoThrow([self.mixpanel unregisterSuperProperty:@"a"],
                     @"unregister non-existent super property should not throw");
    
    [self.mixpanel clearSuperProperties];
    [self waitForSerialQueue];
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"clear super properties failed");
}

- (void)testInvalidPropertiesTrack {
    NSDictionary *p = @{ @"data": [NSData data] };
    XCTAssertThrows([self.mixpanel track:@"e1" properties:p], @"property type should not be allowed");
}

- (void)testInvalidSuperProperties {
    NSDictionary *p = @{ @"data": [NSData data] };
    XCTAssertThrows([self.mixpanel registerSuperProperties:p], @"property type should not be allowed");
    XCTAssertThrows([self.mixpanel registerSuperPropertiesOnce:p], @"property type should not be allowed");
    XCTAssertThrows([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"], @"property type should not be allowed");
}

- (void)testValidPropertiesTrack {
    NSDictionary *p = [self allPropertyTypes];
    XCTAssertNoThrow([self.mixpanel track:@"e1" properties:p], @"property type should be allowed");
}

- (void)testValidSuperProperties {
    NSDictionary *p = [self allPropertyTypes];
    XCTAssertNoThrow([self.mixpanel registerSuperProperties:p], @"property type should be allowed");
    XCTAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p],  @"property type should be allowed");
    XCTAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"],  @"property type should be allowed");
}

#if !defined(MIXPANEL_TVOS_EXTENSION)
- (void)testTrackLaunchOptions {
    NSDictionary *launchOptions = @{ UIApplicationLaunchOptionsRemoteNotificationKey: @{
                                             @"mp": @{
                                                     @"m": @"the_message_id",
                                                     @"c": @"the_campaign_id"
                                                     }
                                             }
                                     };
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:launchOptions
                                   andFlushInterval:60];
    [self waitForSerialQueue];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(e[@"event"], @"$app_open", @"incorrect event name");
    
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"campaign_id"], @"the_campaign_id", @"campaign_id not equal");
    XCTAssertEqualObjects(p[@"message_id"], @"the_message_id", @"message_id not equal");
    XCTAssertEqualObjects(p[@"message_type"], @"push", @"type does not equal inapp");
}
#endif

- (void)testTrackPushNotification {
    [self.mixpanel trackPushNotification:@{ @"mp": @{
                                                    @"m": @"the_message_id",
                                                    @"c": @"the_campaign_id"
                                                    }
                                            }];
    [self waitForSerialQueue];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(e[@"event"], @"$campaign_received", @"incorrect event name");
    
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"campaign_id"], @"the_campaign_id", @"campaign_id not equal");
    XCTAssertEqualObjects(p[@"message_id"], @"the_message_id", @"message_id not equal");
    XCTAssertEqualObjects(p[@"message_type"], @"push", @"type does not equal inapp");
}

- (void)testTrackPushNotificationMalformed {
    [self.mixpanel trackPushNotification:@{ @"mp": @{
                                                    @"m": @"the_message_id",
                                                    @"cid": @"the_campaign_id"
                                                    }
                                            }];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
    
    [self.mixpanel trackPushNotification:@{ @"mp": @1 }];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self.mixpanel trackPushNotification:nil];
#pragma clang diagnostic pop
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
    
    [self.mixpanel trackPushNotification:@{}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
    
    [self.mixpanel trackPushNotification:@{ @"mp": @"bad value" }];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
    
    NSDictionary *badUserInfo = @{ @"mp": @{
                                           @"m": [NSData data],
                                           @"c": [NSData data]
                                           }
                                   };
    XCTAssertThrows([self.mixpanel trackPushNotification:badUserInfo], @"property types should not be allowed");
    
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"Invalid push notification was incorrectly queued.");
}

- (void)testReset {
    [self.mixpanel identify:@"d1"];
    [self.mixpanel track:@"e1"];
    [self.mixpanel setNameTag:@"n1"];
    
    NSDictionary *p = @{ @"p1": @"a" };
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel.people set:p];
    
    [self.mixpanel archive];
    [self.mixpanel reset];
    [self waitForSerialQueue];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset");
    XCTAssertNil(self.mixpanel.nameTag, @"name tag failed to reset");
    XCTAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset");
    XCTAssertTrue([self.mixpanel currentSuperProperties].count == 0, @"super properties failed to reset");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset");
    
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
    [self waitForSerialQueue];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset after archive");
    XCTAssertNil(self.mixpanel.nameTag, @"name tag failed to reset after archive");
    XCTAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset after archive");
    XCTAssertTrue([self.mixpanel currentSuperProperties].count == 0, @"super properties failed to reset after archive");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset after archive");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset after archive");
}

- (void)testArchive {
    [self.mixpanel archive];
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id archive failed");
    XCTAssertNil(self.mixpanel.nameTag, @"default name tag archive failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties archive failed");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue archive failed");
    XCTAssertNil(self.mixpanel.people.distinctId, @"default people distinct id archive failed");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue archive failed");
    
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel identify:@"d1"];
    self.mixpanel.nameTag = @"n1";
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people set:p];
    self.mixpanel.timedEvents[@"e2"] = @5.0;
    [self waitForSerialQueue];
    
    [self.mixpanel archive];
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
    [self waitForSerialQueue];
    XCTAssertEqualObjects(self.mixpanel.distinctId, @"d1", @"custom distinct archive failed");
    XCTAssertEqualObjects(self.mixpanel.nameTag, @"n1", @"custom name tag archive failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 1, @"custom super properties archive failed");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"e1", @"event was not successfully archived/unarchived");
    XCTAssertEqualObjects(self.mixpanel.people.distinctId, @"d1", @"custom people distinct id archive failed");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"pending people queue archive failed");
    XCTAssertEqualObjects(self.mixpanel.timedEvents[@"e2"], @5.0, @"timedEvents archive failed");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"events archive file not removed");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"people archive file not removed");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"properties archive file not removed");
    
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
    XCTAssertEqualObjects(self.mixpanel.distinctId, @"d1", @"expecting d1 as distinct id as initialised");
    XCTAssertEqualObjects(self.mixpanel.nameTag, @"n1", @"expecting n1 as distinct id as initialised");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 1, @"default super properties expected to have 1 item");
    XCTAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from no file is nil");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"default events queue expecting 1 item");
    XCTAssertNotNil(self.mixpanel.people.distinctId, @"default people distinct id from no file failed");
    XCTAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from no file is nil");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"default people queue expecting 1 item");
    XCTAssertTrue(self.mixpanel.timedEvents.count == 1, @"timedEvents expecting 1 item");
    
    // corrupt file
    NSData *garbage = [@"garbage" dataUsingEncoding:NSUTF8StringEncoding];
    [garbage writeToFile:[self.mixpanel eventsFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel peopleFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel propertiesFilePath] atomically:NO];
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"garbage events archive file not found");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"garbage people archive file not found");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"garbage properties archive file not found");
    
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
    [self waitForSerialQueue];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id from garbage failed");
    XCTAssertNil(self.mixpanel.nameTag, @"default name tag archive from garbage failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties from garbage failed");
    XCTAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from garbage is nil");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue from garbage not empty");
    XCTAssertNil(self.mixpanel.people.distinctId, @"default people distinct id from garbage failed");
    XCTAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from garbage is nil");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue from garbage not empty");
    XCTAssertTrue(self.mixpanel.timedEvents.count == 0, @"timedEvents is not empty");
}

- (void)testMixpanelDelegate {
    self.mixpanelWillFlush = NO;
    self.mixpanel.delegate = self;
    
    [self.mixpanel identify:@"d1"];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    [self.mixpanel flush];
    [self waitForSerialQueue];
    
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"delegate should have stopped flush");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"delegate should have stopped flush");
}

- (void)testNilArguments {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSString *originalDistinctID = self.mixpanel.distinctId;
    [self.mixpanel identify:nil];
    XCTAssertEqualObjects(self.mixpanel.distinctId, originalDistinctID, @"identify nil should do nothing.");
    
    [self.mixpanel track:nil];
    [self.mixpanel track:nil properties:nil];
    [self.mixpanel registerSuperProperties:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil defaultValue:nil];
    [self waitForSerialQueue];
    // legacy behavior
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 2, @"track with nil should create mp_event event");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"mp_event", @"track with nil should create mp_event event");
    XCTAssertNotNil([self.mixpanel currentSuperProperties], @"setting super properties to nil should have no effect");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"setting super properties to nil should have no effect");
    
    XCTAssertThrows([self.mixpanel.people set:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:nil to:@"a"], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:@"p1" to:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:nil to:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil by:@3], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:@"p1" by:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil by:nil], @"should not take nil argument");
#pragma clang diagnostic pop
}

- (void)testEventTiming {
    [self.mixpanel track:@"Something Happened"];
    [self waitForSerialQueue];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"New events should not be timed.");

    [self.mixpanel timeEvent:@"400 Meters"];

    [self.mixpanel track:@"500 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"The exact same event name is required for timing.");

    [self.mixpanel track:@"400 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNotNil(p[@"$duration"], @"This event should be timed.");

    [self.mixpanel track:@"400 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"Tracking the same event should require a second call to timeEvent.");
}

#if !defined(MIXPANEL_TVOS_EXTENSION)
- (void)testTelephonyInfoInitialized {
    XCTAssertNotNil([self.mixpanel performSelector:@selector(telephonyInfo)], @"telephonyInfo wasn't initialized");
}
#endif

@end
