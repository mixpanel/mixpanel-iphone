//
//  MixpanelBaseTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Nocilla/Nocilla.h>
#import "MixpanelBaseTests.h"
#import "TestConstants.h"
#import "MixpanelPrivate.h"

@implementation MixpanelBaseTests

- (void)setUp {
    [super setUp];
    
    // HTTP Stubs
    [[LSNocilla sharedInstance] start];

    self.mixpanelWillFlush = NO;
    [self setUpMixpanel];
}

- (void)tearDown {
    [super tearDown];

    [self tearDownMixpanel];

    // HTTP Stubs
    [[LSNocilla sharedInstance] stop];
    [[LSNocilla sharedInstance] clearStubs];
}

- (void)setUpMixpanel {
    self.mixpanel = [[Mixpanel alloc] initWithToken:kTestToken
                                      launchOptions:nil
                                   andFlushInterval:60];
}

- (void)tearDownMixpanel {
    // stub track and engage temporarily because reset flushes. unstub after
    stubTrack();
    stubEngage();
    [self.mixpanel reset];
    [self waitForMixpanelQueues];
    [self deleteOptOutSettingsWithMixpanelInstance:self.mixpanel];

    self.mixpanel = nil;
}

- (void)deleteOptOutSettingsWithMixpanelInstance:(Mixpanel *)MixpanelInstance {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *filename = [MixpanelInstance optOutFilePath];
    [manager removeItemAtPath:filename error:&error];
}

#pragma mark - Mixpanel Delegate
- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel {
    return self.mixpanelWillFlush;
}

#pragma mark - Test Helpers
- (void)flushAndWaitForMixpanelQueues {
    [self.mixpanel flush];
    [self waitForMixpanelQueues];
}

- (void)waitForMixpanelQueues {
    dispatch_sync(self.mixpanel.serialQueue, ^{
        dispatch_sync(self.mixpanel.networkQueue, ^{ return; });
    });
}

- (void)waitForAsyncQueue {
    __block BOOL hasCalledBack = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ hasCalledBack = true; });
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
    while (hasCalledBack == NO && [loopUntil timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
    }
}

- (void)assertDefaultPeopleProperties:(NSDictionary *)p {
    XCTAssertNotNil(p[@"$ios_device_model"], @"missing $ios_device_model property");
    XCTAssertNotNil(p[@"$ios_lib_version"], @"missing $ios_lib_version property");
    XCTAssertNotNil(p[@"$ios_version"], @"missing $ios_version property");
    XCTAssertNotNil(p[@"$ios_app_version"], @"missing $ios_app_version property");
    XCTAssertNotNil(p[@"$ios_app_release"], @"missing $ios_app_release property");
}

- (NSDictionary *)allPropertyTypes {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss zzz";
    NSDate *date = [dateFormatter dateFromString:@"2012-09-28 19:14:36 PDT"];
    NSDictionary *nested = @{@"p1": @{@"p2": @[@{@"p3": @[@"bottom"]}]}};
    return @{ @"string": @"yello", @"number": @3, @"date": date, @"dictionary": @{@"k": @"v"},
              @"array": @[@"1"], @"null": [NSNull null], @"nested": nested,
              @"url": [NSURL URLWithString:@"https://mixpanel.com/"], @"float": @1.3 };
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

@end
