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
#import <StoreKit/StoreKit.h>

@interface AutomaticEvents() <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@end

@implementation AutomaticEvents {
    NSMutableDictionary *awaitingTransactions;
    NSUserDefaults *defaults;
    NSTimeInterval sessionLength;
    NSTimeInterval sessionStartTime;
    MixpanelPeople *people;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        awaitingTransactions = [[NSMutableDictionary alloc] init];
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
        sessionLength = 0;
        sessionStartTime = [[NSDate date] timeIntervalSince1970];
        self.minimumSessionDuration = 10000;
        self.maximumSessionDuration = UINT64_MAX;
    }
    return self;
}

- (void)initializeEvents:(MixpanelPeople *)peopleInstance {
    people = peopleInstance;
    NSString *firstOpenKey = @"MPFirstOpen";
    if (defaults != nil && ![defaults boolForKey:firstOpenKey]) {
        if (![self isExistingUser]) {
            [self.delegate track:@"$ae_first_open" properties:nil];
            [people setOnce:@{@"$ae_first_app_open_date": [NSDate date]}];
        }
        [defaults setBool:TRUE forKey:firstOpenKey];
        [defaults synchronize];
    }

    NSDictionary* infoDict = [NSBundle mainBundle].infoDictionary;
    if (defaults != nil && infoDict != nil) {
        NSString* appVersionKey = @"MPAppVersion";
        NSString* appVersionValue = infoDict[@"CFBundleShortVersionString"];
        NSString* savedVersionValue = [defaults stringForKey:appVersionKey];
        if (appVersionValue != nil && savedVersionValue != nil &&
            [appVersionValue compare:savedVersionValue options:NSNumericSearch] == NSOrderedDescending) {
            [self.delegate track:@"$ae_updated" properties:@{@"$ae_updated_version": appVersionValue}];
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

}

- (void)appWillResignActive:(NSNotification *)notification {
    sessionLength = [self roundOneDigit:[[NSDate date] timeIntervalSince1970] - sessionStartTime];
    if (sessionLength >= (double)(self.minimumSessionDuration / 1000) &&
        sessionLength <= (double)(self.maximumSessionDuration / 1000)) {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc]
                                           initWithObjectsAndKeys:[NSNumber numberWithDouble:sessionLength], @"$ae_session_length", nil];
        [self.delegate track:@"$ae_session" properties:properties];
        [people increment:@"$ae_total_app_sessions" by:[NSNumber numberWithInt:1]];
        [people increment:@"$ae_total_app_session_length" by:[NSNumber numberWithInt:(int)sessionLength]];
    }
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
    if ([productIdentifiers count] > 0) {
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
        productsRequest.delegate = self;
        [productsRequest start];
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    @synchronized (awaitingTransactions) {
        for (SKProduct *product in response.products) {
            SKPaymentTransaction *transaction = [awaitingTransactions objectForKey:product.productIdentifier];
            if (transaction != nil) {
                [self.delegate track:@"$ae_iap" properties:@{@"$ae_iap_price": product.price,
                                                          @"$ae_iap_quantity": [NSNumber numberWithInteger:transaction.payment.quantity],
                                                              @"$ae_iap_name": product.productIdentifier}];
            }
        }
    }
}

- (NSTimeInterval)roundOneDigit:(NSTimeInterval) num {
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

@end
