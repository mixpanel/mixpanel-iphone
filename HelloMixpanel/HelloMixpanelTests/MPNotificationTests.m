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
#import "MPMiniNotification.h"
#import "MPTakeoverNotification.h"
#import "MPNotificationViewController.h"

@interface MPNotificationTests : MixpanelBaseTests

@end

@implementation MPNotificationTests


- (void)testMalformedImageURL {
    NSData *notificationData = [@"{\"id\": 1234, \"message_id\": 4444, \"title\": \"This is a title\", \"title_color\": 4294901760, \"body\": \"This is a body\", \"body_color\": 4294901760, \"image_url\": \"1466606494290.684919.uwp5.png\", \"close_color\": 4294901760, \"type\": \"takeover\", \"bg_color\": 0, \"buttons\": [{\"bg_color\": 0, \"text\": \"Yes!\", \"border_color\": 4294901760, \"text_color\": 4294901760, \"cta_url\": \"mixpanel://deeplink/howareyou\"}],\"extras\": {\"image_fade\": true}}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:notificationData options:0 error:nil];

    XCTAssertNoThrow([[MPTakeoverNotification alloc] initWithJSONObject:info]);

    MPNotification *notification = [[MPTakeoverNotification alloc] initWithJSONObject:info];
    XCTAssertEqualObjects(notification.imageURL.absoluteString, @"1466606494290.684919.uwp5@2x.png");
}

- (void)testParseTakeOverNotification {
    NSData *takeOverNotificationData = [@"{\"id\": 1234, \"message_id\": 4444, \"title\": \"This is a title\", \"title_color\": 4294901760, \"body\": \"This is a body\", \"body_color\": 4294901760, \"image_url\": \"http://mixpanel.com/coolimage.png\", \"close_color\": 4294901760, \"type\": \"takeover\", \"bg_color\": 0, \"buttons\": [{\"bg_color\": 0, \"text\": \"Yes!\", \"border_color\": 4294901760, \"text_color\": 4294901760, \"cta_url\": \"mixpanel://deeplink/howareyou\"}],\"extras\": {\"image_fade\": true}, \"display_triggers\": [{\"event\": \"test_event\", \"selector\":{\"operator\": \"defined\", \"children\": [{\"property\": \"event\", \"value\": \"prop1\"}]}}]}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:takeOverNotificationData options:0 error:nil];

    XCTAssertNotNil([[MPTakeoverNotification alloc] initWithJSONObject:notifDict]);
    
    // nil
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:nil]);
    
    // empty
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:@{}]);
    
    // garbage keys
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:@{@"gar": @"bage"}]);
    
    NSMutableDictionary *testDict;
    
    // invalid id
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"id"] = @NO;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // invalid body color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"body_color"] = @"#FFFFFFFF";
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // invalid background color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"bg_color"] = @"#FFFFFFFF";
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // invalid image_urls item
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"image_url"] = @[@NO];
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // an image with a space in the URL should be % encoded
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"image_url"] = @"https://test.com/animagewithaspace init.jpg";
    XCTAssertNotNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid title color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"title_color"] = @"#FFFFFFFF";
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid close color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"close_color"] = @"#FFFFFFFF";
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid buttons
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"buttons"] = @{};
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    NSMutableArray *buttonsArray;
    NSMutableDictionary *firstButtonDict;

    // invalid button property background color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    buttonsArray = [testDict[@"buttons"] mutableCopy];
    firstButtonDict = [[buttonsArray objectAtIndex:0] mutableCopy];
    firstButtonDict[@"bg_color"] = @"acolor";
    [buttonsArray setObject:firstButtonDict atIndexedSubscript:0];
    testDict[@"buttons"] = buttonsArray;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid button property text
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    buttonsArray = [testDict[@"buttons"] mutableCopy];
    firstButtonDict = [[buttonsArray objectAtIndex:0] mutableCopy];
    firstButtonDict[@"text"] = [NSNull null];
    [buttonsArray setObject:firstButtonDict atIndexedSubscript:0];
    testDict[@"buttons"] = buttonsArray;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid button property border color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    buttonsArray = [testDict[@"buttons"] mutableCopy];
    firstButtonDict = [[buttonsArray objectAtIndex:0] mutableCopy];
    firstButtonDict[@"border_color"] = @"#FFFFFFFF";
    [buttonsArray setObject:firstButtonDict atIndexedSubscript:0];
    testDict[@"buttons"] = buttonsArray;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid button property text color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    buttonsArray = [testDict[@"buttons"] mutableCopy];
    firstButtonDict = [[buttonsArray objectAtIndex:0] mutableCopy];
    firstButtonDict[@"text_color"] = @"#FFFFFFFF";
    [buttonsArray setObject:firstButtonDict atIndexedSubscript:0];
    testDict[@"buttons"] = buttonsArray;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // valid button property cta url
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    buttonsArray = [testDict[@"buttons"] mutableCopy];
    firstButtonDict = [[buttonsArray objectAtIndex:0] mutableCopy];
    firstButtonDict[@"cta_url"] = [NSNull null];
    [buttonsArray setObject:firstButtonDict atIndexedSubscript:0];
    testDict[@"buttons"] = buttonsArray;
    XCTAssertNotNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);

    // invalid fade image
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    NSMutableDictionary *extraDict = [testDict[@"extras"] mutableCopy];
    extraDict[@"image_fade"] = @"mixpanel";
    testDict[@"extras"] = extraDict;
    XCTAssertNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // valid - no display triggers
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    [testDict removeObjectForKey:@"display_triggers"];
    XCTAssertNotNil([[MPTakeoverNotification alloc] initWithJSONObject:testDict]);
    
    // valid - with display triggers
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    MPTakeoverNotification *notif = [[MPTakeoverNotification alloc] initWithJSONObject:testDict];
    XCTAssertTrue([notif hasDisplayTriggers]);
    MPDisplayTrigger *trigger = [notif displayTriggers][0];
    XCTAssertTrue([[trigger selector] count] > 0);
}

- (void)testMiniNotification {
    NSData *miniNotificationData = [@"{\"id\": 1234, \"message_id\": 4444, \"body\": \"This is a body\", \"body_color\": 4294901760, \"image_tint_color\": 33283444, \"border_color\": 452243332, \"cta_url\": null, \"image_url\": \"https//mixpanel.com/image\", \"close_color\": 4294901760, \"type\": \"mini\", \"bg_color\": 0,\"extras\": {}, \"display_triggers\": [{\"event\": \"test_event\", \"selector\":{\"operator\": \"==\", \"children\": [{\"property\": \"event\", \"value\": \"prop1\"}, {\"property\": \"literal\", \"value\": \"test_value\"}]}}]}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:miniNotificationData options:0 error:nil];

    XCTAssertNotNil([[MPMiniNotification alloc] initWithJSONObject:notifDict]);

    NSMutableDictionary *testDict;

    // invalid cta url
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"cta_url"] = @NO;
    XCTAssertNil([[MPMiniNotification alloc] initWithJSONObject:testDict]);

    // invalid image tint color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"image_tint_color"] = @"red";
    XCTAssertNil([[MPMiniNotification alloc] initWithJSONObject:testDict]);

    // invalid boder color
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    testDict[@"border_color"] = @"#FFFFFFFF";
    XCTAssertNil([[MPMiniNotification alloc] initWithJSONObject:testDict]);
    
    // valid - no display triggers
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    [testDict removeObjectForKey:@"display_triggers"];
    XCTAssertNotNil([[MPMiniNotification alloc] initWithJSONObject:testDict]);
    
    // valid - with display triggers
    testDict = [NSMutableDictionary dictionaryWithDictionary:notifDict];
    MPMiniNotification *notif = [[MPMiniNotification alloc] initWithJSONObject:testDict];
    XCTAssertTrue([notif hasDisplayTriggers]);
    
    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
    event[@"event"] = @"test_event_1";
    XCTAssertFalse([notif matchesEvent:event]);
    event[@"event"] = @"test_event";
    XCTAssertFalse([notif matchesEvent:event]);
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    properties[@"prop"] = @"test";
    event[@"properties"] = properties;
    XCTAssertFalse([notif matchesEvent:event]);
    properties[@"prop1"] = @"blah";
    XCTAssertFalse([notif matchesEvent:event]);
    properties[@"prop1"] = @"test_value";
    XCTAssertTrue([notif matchesEvent:event]);
}

- (void)testNoDoubleShowNotification {
    [[LSNocilla sharedInstance] stop];

    NSData *notificationData = [@"{\"id\": 1234, \"message_id\": 4444, \"title\": \"This is a title\", \"title_color\": 4294901760, \"body\": \"This is a body\", \"body_color\": 4294901760, \"image_url\": \"https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png\", \"close_color\": 4294901760, \"type\": \"takeover\", \"bg_color\": 0, \"buttons\": [{\"bg_color\": 0, \"text\": \"Yes!\", \"border_color\": 4294901760, \"text_color\": 4294901760, \"cta_url\": \"mixpanel://deeplink/howareyou\"}],\"extras\": {\"image_fade\": true}}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:notificationData options:0 error:nil];

    NSUInteger numWindows = [UIApplication sharedApplication].windows.count;
    
    MPTakeoverNotification *notif = [[MPTakeoverNotification alloc]initWithJSONObject:notifDict];
    [self.mixpanel showNotificationWithObject:notif];
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    XCTAssertTrue([UIApplication sharedApplication].windows.count == numWindows + 1, @"Notification was not presented");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"should only show same notification once (and track 1 notif shown event)");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"$campaign_delivery", @"last event should be campaign delivery");
    

    XCTestExpectation *expectation = [self expectationWithDescription:@"notification closed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.mixpanel.currentlyShowingNotification = nil;
        self.mixpanel.notificationViewController = nil;
        MPNotificationViewController *notificationViewController = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if ([window.rootViewController isKindOfClass:[MPNotificationViewController class]]) {
                notificationViewController = (MPNotificationViewController *) window.rootViewController;
                break;
            }
        }
        
        if (notificationViewController) {
            [notificationViewController hide:YES completion:^{
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

    NSData *notificationData = [@"{\"id\": 1234, \"message_id\": 4444, \"title\": \"This is a title\", \"title_color\": 4294901760, \"body\": \"This is a body\", \"body_color\": 4294901760, \"image_url\": \"https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png\", \"close_color\": 4294901760, \"type\": \"takeover\", \"bg_color\": 0, \"buttons\": [{\"bg_color\": 0, \"text\": \"Yes!\", \"border_color\": 4294901760, \"text_color\": 4294901760, \"cta_url\": \"mixpanel://deeplink/howareyou\"}],\"extras\": {\"image_fade\": true}}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:notificationData options:0 error:nil];

    NSUInteger numWindows = [UIApplication sharedApplication].windows.count;

    MPTakeoverNotification *notif = [[MPTakeoverNotification alloc]initWithJSONObject:notifDict];
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    topVC = [self topViewController];
    XCTAssertFalse([UIApplication sharedApplication].windows.count == numWindows + 1, @"Notification was presented");

    XCTAssertFalse([topVC isKindOfClass:[MPNotificationViewController class]], @"Notification was presented");
    
    // Dismiss the alert and try to present notification again
    waitForBlock = YES;
    [topVC dismissViewControllerAnimated:YES completion:^{
        waitForBlock = NO;
    }];
    
    while(waitForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    numWindows = [UIApplication sharedApplication].windows.count;
    [self.mixpanel showNotificationWithObject:notif];
    
    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];
    
    XCTAssertTrue([UIApplication sharedApplication].windows.count == numWindows + 1, @"Notification wasn't presented");
}

// Waiting for web/backend to be ready
- (void)testVisualNotifications {
    //This is run on an iPhone 5S Simulator, an iPhone 6S Plus Simulator, and an iPad Pro 9.7in Simulator
//    [[LSNocilla sharedInstance] stop];
//
//    while ([[self topViewController] isKindOfClass:[MPNotificationViewController class]]) {
//        XCTestExpectation *expectation = [self expectationWithDescription:@"notification closed"];
//
//        [((MPNotificationViewController *)[self topViewController]) hide:NO completion:^{
//            [expectation fulfill];
//        }];
//        [self waitForExpectationsWithTimeout:2 handler:nil];
//    }
//    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
//    [((UINavigationController *)[self topViewController]) presentViewController:[UIViewController new] animated:NO completion:nil];
//
//    NSArray *inAppImages = @[@{@"image_url": @"https://images.mxpnl.com/960173/cbcdaf35d399ee84e44c4217f26055ff.jpg",
//                               @"title": @"color grid",
//                               @"body": @"check how much is showing",
//                               @"cta": @"Done"},
//                            @{@"image_url": @"https://images.mxpnl.com/960173/87c3912791f1df168d2900f1397caed1.jpg",
//                               @"title": @"Hello this is a test. The number of characters max",
//                               @"body": @"This is the subject line when there are a maximum number of characters inside of an in-app",
//                               @"cta": @"Submit"},
//                             @{@"image_url": @"https://images.mxpnl.com/960173/e8043acf3dc21ac5604b0956aae99e45.jpg",
//                               @"title": @"Unicode Char Maximum Testing.. 你好 مرحبا שלום こんにちは",
//                               @"body": @"More unicode testing happening. 你好 مرحبا שלום こんにちは Здравствуйте สวัสดี Χαίρετε नमस्ते హలో",
//                               @"cta": @"Submit"},
//                             @{@"image_url": @"https://images.mxpnl.com/960173/780c655459f5b718bc008019edf626c2.jpg",
//                               @"title": @"Very Wide Short Image",
//                               @"body": @"A",
//                               @"cta": @"Submit"},
//                             @{@"image_url": @"https://images.mxpnl.com/960173/c56e0cc7894e7d95d3d8b97aac739bba.png",
//                               @"title": @"Very Tall Thin Image",
//                               @"body": @"This is the subject line when there are a maximum number of characters inside of an in-app",
//                               @"cta": @"Submit"},
//                             @{@"image_url": @"https://images.mxpnl.com/960173/8b60e0ddcf61d34622edcd9214062f86.png",
//                               @"title": @"A",
//                               @"body": @"A",
//                               @"cta": @"Submit"}
//                             ];
//
//    NSArray *orientations = @[@"Portrait", @"Landscape"];
//
//    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        orientations = @[@"Portrait-iPad", @"Landscape-iPad"];
//    }
//    //load notification
//    NSMutableDictionary *notifDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
//                              @3, @"id",
//                              @1, @"message_id",
//                              @"takeover", @"type",
//                              @4294901760, @"body_color",
//                              @4294901760, @"title_color",
//                              @"maps://", @"cta_url",
//                              nil];
//
//    for (NSString *orientation in orientations) {
//        for (NSUInteger i=0; i<[inAppImages count]; i++) {
//
//            [notifDict addEntriesFromDictionary:inAppImages[i]];
//            MPNotification *notif = [MPNotification notificationWithJSONObject:notifDict];
//            [self.mixpanel showNotificationWithObject:notif];
//
//            [self waitForAsyncQueue];
//            if ([[self topViewController] isKindOfClass:[MPNotificationViewController class]]) {
//                MPNotificationViewController* topViewController = (MPNotificationViewController *)[self topViewController];
//                NSString *snapshotName = [NSString stringWithFormat:@"MPNotification-%lu-%@", (unsigned long)i, orientation];
//                FBSnapshotVerifyView(topViewController.view, snapshotName);
//                XCTestExpectation *expectation = [self expectationWithDescription:@"notification closed"];
//                [topViewController hide:NO completion:^{
//                    [expectation fulfill];
//                }];
//                [self waitForExpectationsWithTimeout:2 handler:nil];
//                self.mixpanel.currentlyShowingNotification = nil;
//                self.mixpanel.notificationViewController = nil;
//            } else {
//                XCTAssertTrue(NO, @"Couldn't load notification");
//            }
//        }
//        XCUIDevice *device = [XCUIDevice sharedDevice];
//        device.orientation = UIDeviceOrientationLandscapeLeft;
//    }
}


@end
