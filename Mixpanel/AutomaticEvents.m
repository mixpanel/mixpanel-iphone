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
    NSTimeInterval sessionLength;
    NSTimeInterval sessionStartTime;
    MixpanelPeople *people;
}

static NSTimeInterval _appStartTime;
+ (NSTimeInterval)appStartTime { return _appStartTime; }
+ (void)setAppStartTime:(NSTimeInterval)appStartTime { _appStartTime = appStartTime; }

__attribute__((constructor))
static void initialize_appStartTime() {
    if (AutomaticEvents.appStartTime == 0) {
        AutomaticEvents.appStartTime = [[NSDate date] timeIntervalSince1970];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        awaitingTransactions = [[NSMutableDictionary alloc] init];
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
        sessionLength = 0;
        sessionStartTime = 0;
        self.minimumSessionDuration = 10000;
    }
    return self;
}

- (void)initializeEvents:(MixpanelPeople *)peopleInstance {
    people = peopleInstance;
    NSString *firstOpenKey = @"MPFirstOpen";
    if (defaults != nil && ![defaults boolForKey:firstOpenKey]) {
        if (![self isExistingUser]) {
            [self.delegate track:@"$ae_first_open" properties:nil];
            [people setOnce:@{@"First App Open Date": [NSDate date]}];
        }
        [defaults setBool:TRUE forKey:firstOpenKey];
        [defaults synchronize];
    }

    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    if (defaults != nil && infoDict != nil) {
        NSString* appVersionKey = @"MPAppVersion";
        NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
        NSString* savedVersionValue = [defaults stringForKey:appVersionKey];
        if (appVersionValue != nil && savedVersionValue != nil && ![appVersionValue isEqualToString:savedVersionValue]) {
            [self.delegate track:@"$ae_updated" properties:@{@"App Version": appVersionValue}];
            [defaults setObject:appVersionValue forKey:appVersionKey];
            [defaults synchronize];
        } else if (savedVersionValue == nil) {
            [defaults setObject:appVersionValue forKey:appVersionKey];
            [defaults synchronize];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
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
                              [self.delegate track:@"$ae_notif_opened" properties:nil];
                          }
                              named:@"notification opened"];
    }

}

- (void)appWillResignActive:(NSNotification *)notification {
    sessionLength = [self roundThreeDigits:[[NSDate date] timeIntervalSince1970] - sessionStartTime];
    if (sessionLength > (double)(self.minimumSessionDuration / 1000)) {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc]
                                           initWithObjectsAndKeys:[NSNumber numberWithDouble:sessionLength], @"Session Length", nil];
        [self.delegate track:@"$ae_session" properties:properties];
        [people increment:@"Total App Sessions" by:[NSNumber numberWithInt:1]];
        [people increment:@"Total App Session Length" by:[NSNumber numberWithInt:(int)sessionLength]];
    }
    AutomaticEvents.appStartTime = 0;
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
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

- (NSTimeInterval)roundThreeDigits:(NSTimeInterval) num {
    return round(num * 10.0) / 10.0;
}

- (BOOL)isExistingUser {
    NSString *searchPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSArray<NSString *> *pathContents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:searchPath error:nil];
    for (NSString *path in pathContents) {
        if ([path hasPrefix:@"mixpanel-"]) {
            return true;
        }
    }
    return false;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    @synchronized (awaitingTransactions) {
        for (SKProduct *product in response.products) {
            SKPaymentTransaction *transaction = [awaitingTransactions objectForKey:product.productIdentifier];
            if (transaction != nil) {
                [self.delegate track:@"$ae_iap" properties:@{@"Price": product.price,
                                                                         @"Quantity": [NSNumber numberWithInteger:transaction.payment.quantity],
                                                                         @"Product Name": product.productIdentifier}];
            }
        }
    }
}
@end
