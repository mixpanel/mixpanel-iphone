//
//  MPNotificationTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Nocilla/Nocilla.h>
#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"

@interface MPNotificationTests : MixpanelBaseTests

@end

@implementation MPNotificationTests

- (void)testParseNotification {
    // invalid bad title
    NSDictionary *invalid = @{@"id": @3,
                              @"title": @5,
                              @"type": @"takeover",
                              @"style": @"dark",
                              @"body": @"Hi!",
                              @"cta_url": @"blah blah blah",
                              @"cta": [NSNull null],
                              @"image_url": @[]};
    
    XCTAssertNil([MPNotification notificationWithJSONObject:invalid]);
    
    // valid
    NSDictionary *o = @{@"id": @3,
                        @"message_id": @1,
                        @"title": @"title",
                        @"type": @"takeover",
                        @"style": @"dark",
                        @"body": @"body",
                        @"cta": @"cta",
                        @"cta_url": @"maps://",
                        @"image_url": @"http://mixpanel.com/coolimage.png"};
    
    XCTAssertNotNil([MPNotification notificationWithJSONObject:o]);
    
    // nil
    XCTAssertNil([MPNotification notificationWithJSONObject:nil]);
    
    // empty
    XCTAssertNil([MPNotification notificationWithJSONObject:@{}]);
    
    // garbage keys
    XCTAssertNil([MPNotification notificationWithJSONObject:@{@"gar": @"bage"}]);
    
    NSMutableDictionary *m;
    
    // invalid id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"id"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid title
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"title"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid body
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"body"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid cta
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"cta"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid cta_url
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"cta_url"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid image_urls
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // invalid image_urls item
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @[@NO];
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);
    
    // an image with a space in the URL should be % encoded
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @"https://test.com/animagewithaspace init.jpg";
    XCTAssertNotNil([MPNotification notificationWithJSONObject:m]);
}

- (void)testNoDoubleShowNotification {
    [[LSNocilla sharedInstance] stop];
    
    NSDictionary *o = @{@"id": @3,
                        @"message_id": @1,
                        @"title": @"title",
                        @"type": @"takeover",
                        @"style": @"dark",
                        @"body": @"body",
                        @"cta": @"cta",
                        @"cta_url": @"maps://",
                        @"image_url": @"https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png"};
    MPNotification *notif = [MPNotification notificationWithJSONObject:o];
    [self.mixpanel showNotificationWithObject:notif];
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    UIViewController *topVC = [self topViewController];
    XCTAssertTrue([topVC isKindOfClass:[MPNotificationViewController class]], @"Notification was not presented");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"should only show same notification once (and track 1 notif shown event)");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"$campaign_delivery", @"last event should be campaign delivery");
    

    XCTestExpectation *expectation = [self expectationWithDescription:@"notification closed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.mixpanel.currentlyShowingNotification = nil;
        self.mixpanel.notificationViewController = nil;
        if([topVC isKindOfClass:[MPNotificationViewController class]]) {
            [(MPNotificationViewController *)topVC hideWithAnimation:YES completion:^void{
                [expectation fulfill];
            }];
        }
    });
    [self waitForExpectationsWithTimeout:self.mixpanel.miniNotificationPresentationTime * 2 handler:nil];
}

- (void)testNoShowNotificationOnAlertController {
    [[LSNocilla sharedInstance] stop];
    
    UIViewController *topVC = [self topViewController];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:nil]];
    
    __block BOOL waitForBlock = YES;
    [topVC presentViewController:alertController animated:NO completion:^{
        waitForBlock = NO;
    }];
    
    while(waitForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    NSDictionary *o = @{@"id": @3,
                        @"message_id": @1,
                        @"title": @"title",
                        @"type": @"takeover",
                        @"style": @"dark",
                        @"body": @"body",
                        @"cta": @"cta",
                        @"cta_url": @"maps://",
                        @"image_url": @"https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png"};
    MPNotification *notif = [MPNotification notificationWithJSONObject:o];
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    topVC = [self topViewController];
    XCTAssertFalse([topVC isKindOfClass:[MPNotificationViewController class]], @"Notification was presented");
    
    // Dismiss the alert and try to present notification again
    waitForBlock = YES;
    [topVC dismissViewControllerAnimated:YES completion:^{
        waitForBlock = NO;
    }];
    
    while(waitForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    topVC = [self topViewController];
    XCTAssertTrue([topVC isKindOfClass:[MPNotificationViewController class]], @"Notification wasn't presented");
}

@end
