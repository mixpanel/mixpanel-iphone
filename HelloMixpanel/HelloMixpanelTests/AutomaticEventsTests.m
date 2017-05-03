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

@interface AutomaticEventsTests : MixpanelBaseTests <SKProductsRequestDelegate, SKPaymentTransactionObserver>

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
    NSString *searchPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    [NSFileManager.defaultManager removeItemAtPath:searchPath error:nil];
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
    [self.mixpanel.automaticEvents performSelector:NSSelectorFromString(@"appWillResignActive:") withObject:nil];
    [self waitForMixpanelQueues];
    NSDictionary *event = [self.mixpanel.eventsQueue lastObject];
    XCTAssertNotNil(event, @"should have an event");
    XCTAssert([event[@"event"] isEqualToString:@"$ae_session"], @"should be app session event");
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
        XCTAssert([event[@"event"] isEqualToString:@"$ae_notif_opened"], @"should be an notificaiton opened event");
    }
    [self waitForMixpanelQueues];
}

- (void)testIAP {
    NSSet<NSString *> *productIdentifiers = [[NSSet alloc] initWithObjects:@"com.mixpanel.swiftdemo.test",
                                             @"test",
                                             @"com.mixpanel.swiftdemo.SwiftSDKIAPTestingProductID",
                                             @"SwiftSDKIAPTestingProductID",
                                             @"mixpanel.swiftdemo.test", nil];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count > 0) {
        if (response.products.firstObject) {
            SKPayment *payment = [SKPayment paymentWithProduct:response.products.firstObject];
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"IAP Purchased");
                break;
            case SKPaymentTransactionStateFailed:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"IAP Failed");
                break;
            case SKPaymentTransactionStateRestored:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"IAP Restored");
                break;
            default:
                break;
        }
    }
}

@end
