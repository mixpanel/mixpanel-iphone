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
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@interface AutomaticEventsTests : MixpanelBaseTests

//@property (nonatomic, strong) AutomaticEvents *automaticEvents;

@end

@implementation AutomaticEventsTests {
    NSTimeInterval startTime;
}


- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *firstOpenKey = @"MPFirstOpen";
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    [defaults setObject:nil forKey:firstOpenKey];
    [defaults synchronize];
    [super setUp];
    startTime = [[NSDate date] timeIntervalSince1970];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFirstOpen {
    [self waitForMixpanelQueues];
    XCTAssert(self.mixpanel.eventsQueue.count == 1, @"First App Open Should be tracked");
}

- (void)testSession {
    [self.mixpanel.automaticEvents performSelector:NSSelectorFromString(@"appEnteredBackground:") withObject:nil];
    [self waitForMixpanelQueues];
    NSDictionary *event = [self.mixpanel.eventsQueue lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"MP: App Session"], @"should be app session event");
    XCTAssertNotNil(event[@"properties"][@"Session Length"], @"should have session length");
}

- (void)testUpdated {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
    NSString* savedVersionValue = [defaults stringForKey:@"MPAppVersion"];
    XCTAssert(appVersionValue == savedVersionValue, @"saved version and current version need to be the same");
}

- (void)testCrash {
    //crash your app and see it track
    //[self performSelector:@selector(die_die)];
}

- (void)testPushNotificationOpened {
    SEL selector = nil;
    Class cls = [[UIApplication sharedApplication].delegate class];
    if (class_getInstanceMethod(cls, NSSelectorFromString(@"application:didReceiveRemoteNotification:fetchCompletionHandler:"))) {
        selector = NSSelectorFromString(@"application:didReceiveRemoteNotification:fetchCompletionHandler:");
        [[UIApplication sharedApplication].delegate performSelector:selector withObject:@{@"testingAutomaticEvents":@TRUE} withObject:nil];
    } else if (class_getInstanceMethod(cls, NSSelectorFromString(@"application:didReceiveRemoteNotification:"))) {
        selector = NSSelectorFromString(@"application:didReceiveRemoteNotification:");
        [[UIApplication sharedApplication].delegate performSelector:selector withObject:@{@"testingAutomaticEvents":@TRUE}];

    }
    if (selector) {
        [self waitForMixpanelQueues];
        NSDictionary *event = [self.mixpanel.eventsQueue lastObject];
        XCTAssertNotNil(event, @"should have an event");
        XCTAssert([event[@"event"] isEqualToString:@"MP: Notification Opened"], @"should be an notificaiton opened event");
    }
    [self waitForMixpanelQueues];
}

- (void)testIAP {

}

@end
