//
//  AutomaticEventsTests.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "AutomaticEvents.h"
#import "MixpanelPrivate.h"
#import <objc/runtime.h>
#import <StoreKit/StoreKit.h>
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"


@interface AutomaticEventsTests : MixpanelBaseTests

//@property (nonatomic, strong) AutomaticEvents *automaticEvents;

@end

@implementation AutomaticEventsTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSession {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.minimumSessionDuration = 0;
    [testMixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues:testMixpanel];
    NSDictionary *event = [[self eventQueue:testMixpanel.apiToken] lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(event[@"properties"][@"$ae_session_length"], @"should have session length");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testUpdated {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
    NSString* savedVersionValue = [defaults stringForKey:@"MPAppVersion"];
    XCTAssert(appVersionValue == savedVersionValue, @"saved version and current version need to be the same");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsFalse {
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:NO andFlushInterval:60];
    testMixpanel.minimumSessionDuration = 0;
    [testMixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqual([self eventQueue:testMixpanel.apiToken].count, 0, @"automatic events should not be tracked");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testTrackAutomaticEventsIftrackAutomaticEventsEnabledIsTrue {
    // since the token does not exist, it will simulate decide being not available
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.minimumSessionDuration = 0;
    [testMixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqual([self eventQueue:testMixpanel.apiToken].count, 1, @"automatic events should be tracked");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsNotSet {
    // since the token does not exist, it will simulate decide being not available
    Mixpanel *testMixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    testMixpanel.minimumSessionDuration = 0;
    [testMixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues:testMixpanel];
    XCTAssertEqual([self eventQueue:testMixpanel.apiToken].count, 1, @"by default, automatic events should be tracked");
    [self removeDBfile:testMixpanel.apiToken];
}

- (void)testMultipleInstances {
    Mixpanel *mp = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    mp.minimumSessionDuration = 0;
    Mixpanel *mp2 = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:YES andFlushInterval:60];
    mp2.minimumSessionDuration = 0;
    [mp2.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [mp.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues:mp];
    [self waitForMixpanelQueues:mp2];
    dispatch_sync(mp.serialQueue, ^{
    });
    NSDictionary *event = [[self eventQueue:mp2.apiToken] lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(event[@"properties"][@"$ae_session_length"], @"should have session length");
    NSDictionary *otherEvent = [[self eventQueue:mp.apiToken] lastObject];
    XCTAssertNotNil(otherEvent, @"should have an event");
    XCTAssert([otherEvent[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(otherEvent[@"properties"][@"$ae_session_length"], @"should have session length");
    [self removeDBfile:mp.apiToken];
    [self removeDBfile:mp2.apiToken];
}

@end
