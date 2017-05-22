//
//  AutomaticEventsTests.m
//  HelloMixpanel
//
//  Created by Yarden Eitan on 4/25/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
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
    self.mixpanel.minimumSessionDuration = 0;
    [self.mixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues];
    NSDictionary *event = [self.mixpanel.eventsQueue lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(event[@"properties"][@"$ae_session_length"], @"should have session length");
}

- (void)testUpdated {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
    NSString* savedVersionValue = [defaults stringForKey:@"MPAppVersion"];
    XCTAssert(appVersionValue == savedVersionValue, @"saved version and current version need to be the same");
}

- (void)testMultipleInstances {
    Mixpanel *mp = [[Mixpanel alloc] initWithToken:@"abc"
                                      launchOptions:nil
                                   andFlushInterval:60];
    mp.minimumSessionDuration = 0;
    self.mixpanel.minimumSessionDuration = 0;
    [self.mixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [mp.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues];
    dispatch_sync(mp.serialQueue, ^{
        dispatch_sync(mp.networkQueue, ^{  });
    });
    NSDictionary *event = [self.mixpanel.eventsQueue lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(event[@"properties"][@"$ae_session_length"], @"should have session length");
    NSDictionary *otherEvent = [mp.eventsQueue lastObject];
    XCTAssertNotNil(otherEvent, @"should have an event");
    XCTAssert([otherEvent[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
    XCTAssertNotNil(otherEvent[@"properties"][@"$ae_session_length"], @"should have session length");
}

@end
