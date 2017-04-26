//
//  AutomaticEvents.m
//  Mixpanel
//
//  Created by Yarden Eitan on 4/18/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "AutomaticEvents.h"
#import "MPSwizzler.h"
#import <objc/runtime.h>


@implementation AutomaticEvents {
    NSMutableDictionary *awaitingTransactions;
    NSUserDefaults *defaults;
    NSTimeInterval appLoadSpeed;
    NSTimeInterval sessionLength;
    NSTimeInterval sessionStartTime;
}

static NSTimeInterval _appStartTime;
+ (NSTimeInterval)appStartTime { return _appStartTime; }
+ (void)setAppStartTime:(NSTimeInterval)appStartTime { _appStartTime = appStartTime; }

__attribute__((constructor))
static void initialize_appStartTime() {
    AutomaticEvents.appStartTime = [[NSDate date] timeIntervalSince1970];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        awaitingTransactions = [[NSMutableDictionary alloc] init];
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
        appLoadSpeed = 0;
        sessionLength = 0;
        sessionStartTime = 0;
    }
    return self;
}

- (void)initializeEvents {
    NSString *firstOpenKey = @"MPFirstOpen";
    if (defaults != nil && ![defaults boolForKey:firstOpenKey]) {
        [self.delegate track:@"MP: First App Open" properties:nil];
        [defaults setBool:TRUE forKey:firstOpenKey];
        [defaults synchronize];
    }

    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    if (defaults != nil && infoDict != nil) {
        NSString* appVersionKey = @"MPAppVersion";
        NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
        NSString* savedVersionValue = [defaults stringForKey:appVersionKey];
        if (appVersionValue != nil && savedVersionValue != nil && appVersionValue != savedVersionValue) {
            [self.delegate track:@"MP: App Updated" properties:@{@"App Version": appVersionValue}];
            [defaults setObject:appVersionValue forKey:appVersionKey];
            [defaults synchronize];
        } else if (savedVersionValue == nil) {
            [defaults setObject:appVersionValue forKey:appVersionKey];
            [defaults synchronize];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    SEL selector = nil;
    Class cls = [[UIApplication sharedApplication].delegate class];
    if (class_getInstanceMethod(cls, NSSelectorFromString(@"application:didReceiveRemoteNotification:fetchCompletionHandler:"))) {
        selector = NSSelectorFromString(@"application:didReceiveRemoteNotification:fetchCompletionHandler:");
    } else if (class_getInstanceMethod(cls, NSSelectorFromString(@"application:didReceiveRemoteNotification:"))) {
        selector = NSSelectorFromString(@"application:didReceiveRemoteNotification:");
    }

    if (selector) {
        [MPSwizzler swizzleSelector:selector
                            onClass:cls
                          withBlock:^{
                              [self.delegate track:@"MP: Notification Opened" properties:nil];
                          }
                              named:@"notification opened"];
    }

}

- (void)appEnteredBackground:(NSNotification *)notification {
    sessionLength = [[NSDate date] timeIntervalSince1970] - sessionStartTime;
    if (sessionLength > (double)(self.minimumSessionDuration / 1000)) {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc]
                                           initWithObjectsAndKeys:[NSNumber numberWithDouble:sessionLength], @"Session Length", nil];
        if (appLoadSpeed > 0) {
            [properties setObject:[NSNumber numberWithUnsignedInt:appLoadSpeed] forKey:@"App Load Speed (ms)"];
        }
        [self.delegate track:@"MP: App Session" properties:properties];
    }
    AutomaticEvents.appStartTime = 0;
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    appLoadSpeed = AutomaticEvents.appStartTime != 0 ? (nowTime - AutomaticEvents.appStartTime) * 1000 : 0;
    sessionStartTime = nowTime;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    NSMutableSet<NSString *> *productIdentifiers = [[NSMutableSet alloc] init];
    @synchronized (awaitingTransactions) {
        for (SKPaymentTransaction *transaction in transactions) {
            if (transaction != nil) {
                switch (transaction.transactionState) {
                    case SKPaymentTransactionStatePurchased:
                        [productIdentifiers addObject:transaction.payment.productIdentifier];
                        [awaitingTransactions setObject:transaction forKey:transaction.payment.productIdentifier];
                        break;
                    case SKPaymentTransactionStateFailed:
                    case SKPaymentTransactionStateRestored:
                    default:
                        break;
                }
            }
        }
    }
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    @synchronized (awaitingTransactions) {
        for (SKProduct *product in response.products) {
            SKPaymentTransaction *transaction = [awaitingTransactions objectForKey:product.productIdentifier];
            if (transaction != nil) {
                [self.delegate track:@"MP: In-App Purchase" properties:@{@"Price": product.price,
                                                                         @"Quantity": [NSNumber numberWithInteger:transaction.payment.quantity],
                                                                         @"Product Name": product.productIdentifier}];
            }
        }
    }
}
@end
