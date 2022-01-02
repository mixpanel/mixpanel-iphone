//
//  MixpanelBaseTests.h
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Mixpanel.h"

@interface MixpanelBaseTests : XCTestCase  <MixpanelDelegate>

@property (nonatomic, strong) Mixpanel *mixpanel;
@property (atomic) BOOL mixpanelWillFlush;

- (void)flushAndWaitForMixpanelQueues:(Mixpanel *)mixpanel;
- (void)waitForMixpanelQueues:(Mixpanel *)mixpanel;
- (void)waitForAsyncQueue;
- (void)removeDBfile:(NSString *)token;

- (UIViewController *)topViewController;
- (void)assertDefaultPeopleProperties:(NSDictionary *)p;
- (NSDictionary *)allPropertyTypes;

- (NSString *)randomTokenId;
- (void)timeDelay;
- (BOOL)isDateString:(NSString *)dateString equalToDate:(NSDate *)date;
- (NSArray *)eventQueue:(NSString *)token;
- (NSArray *)peopleQueue:(NSString *)token;
- (NSArray *)unIdentifiedPeopleQueue:(NSString *)token;
- (NSArray *)groupQueue:(NSString *)token;

@end
