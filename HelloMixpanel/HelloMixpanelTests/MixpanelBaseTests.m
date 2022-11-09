//
//  MixpanelBaseTests.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//
#import <TargetConditionals.h>

#import "MixpanelBaseTests.h"
#import "TestConstants.h"
#import "MixpanelPrivate.h"

#define MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT 1

@implementation MixpanelBaseTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    [defaults setBool:YES forKey:@"MPFirstOpen"];
    self.mixpanelWillFlush = NO;
}

- (void)tearDown {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"Mixpanel"];
    [defaults removeObjectForKey:@"MPFirstOpen"];
    [super tearDown];
}

- (NSString *)randomTokenId {
    NSUInteger randomId = arc4random();
    return [NSString stringWithFormat:@"%lu", (unsigned long)randomId];
}

- (void)timeDelay {
    NSTimeInterval delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
      NSLog(@"Do some work");
    });
}

- (NSArray *)eventQueue:(NSString *)token {
    return [[[MixpanelPersistence alloc] initWithToken:token] loadEntitiesInBatch:PersistenceTypeEvents];
}

- (NSArray *)peopleQueue:(NSString *)token {
    return [[[MixpanelPersistence alloc] initWithToken:token] loadEntitiesInBatch:PersistenceTypePeople];
}

- (NSArray *)unIdentifiedPeopleQueue:(NSString *)token {
    return [[[MixpanelPersistence alloc] initWithToken:token] loadEntitiesInBatch:PersistenceTypePeople flag:UnIdentifiedFlag];
}

- (NSArray *)groupQueue:(NSString *)token {
    return [[[MixpanelPersistence alloc] initWithToken:token] loadEntitiesInBatch:PersistenceTypeGroups];
}

#pragma mark - Mixpanel Delegate
- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel {
    return self.mixpanelWillFlush;
}

#pragma mark - Test Helpers
- (void)flushAndWaitForMixpanelQueues:(Mixpanel *)mixpanel {
    [mixpanel flush];
    [self waitForMixpanelQueues:mixpanel];
}

- (void)waitForMixpanelQueues:(Mixpanel *)mixpanel {
    dispatch_sync(mixpanel.serialQueue, ^{
        dispatch_sync(mixpanel.networkQueue, ^{
            return;
        });
    });
    dispatch_sync(mixpanel.serialQueue, ^{
        dispatch_sync(mixpanel.networkQueue, ^{
            return;
        });
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

- (void)removeDBfile:(NSString *)token {
    NSString *filename = [NSString stringWithFormat:@"%@_MPDB.sqlite", token];
#if !TARGET_OS_TV
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
    if (dbPath) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:dbPath]) {
            NSError *error = nil;
            [manager removeItemAtPath:dbPath error:&error];
            if (error) {
                NSLog(@"Unable to remove database file at path: %@ error: %@", dbPath, error);
            } else {
                NSLog(@"Deleted database file at path: %@", dbPath);
            }
        }
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

- (BOOL)isDateString:(NSString *)dateString equalToDate:(NSDate *)date {
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    NSString *dateString2 = [dateFormatter stringFromDate:date];
    return [[dateString2 substringToIndex:19] isEqualToString: [dateString substringToIndex:19]];
    
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

@end
