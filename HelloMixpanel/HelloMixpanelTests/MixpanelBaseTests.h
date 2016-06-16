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

- (void)flushAndWaitForSerialQueue;
- (void)waitForSerialQueue;
- (void)waitForAsyncQueue;

- (UIViewController *)topViewController;
- (void)assertDefaultPeopleProperties:(NSDictionary *)p;
- (NSDictionary *)allPropertyTypes;

@end
