//
//  MixpanelBaseTests.h
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Mixpanel.h"

@interface MixpanelBaseTests : XCTestCase  <MixpanelDelegate>

@property (nonatomic, strong) Mixpanel *mixpanel;
@property (atomic) BOOL mixpanelWillFlush;

- (void)setUpMixpanel;
- (void)tearDownMixpanel;
- (void)deleteOptOutSettingsWithMixpanelInstance:(Mixpanel *)MixpanelInstance;

- (void)flushAndWaitForMixpanelQueues;
- (void)waitForMixpanelQueues;
- (void)waitForAsyncQueue;

- (UIViewController *)topViewController;
- (void)assertDefaultPeopleProperties:(NSDictionary *)p;
- (NSDictionary *)allPropertyTypes;

@end
