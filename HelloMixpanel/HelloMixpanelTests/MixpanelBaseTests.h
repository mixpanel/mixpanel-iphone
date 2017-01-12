//
//  MixpanelBaseTests.h
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Mixpanel.h"

#if !defined(MIXPANEL_TVOS_EXTENSION)
#import <FBSnapshotTestCase/FBSnapshotTestCase.h>
#endif

#if !defined(MIXPANEL_TVOS_EXTENSION)
@interface MixpanelBaseTests : FBSnapshotTestCase  <MixpanelDelegate>
#else
@interface MixpanelBaseTests : XCTestCase  <MixpanelDelegate>
#endif

@property (nonatomic, strong) Mixpanel *mixpanel;
@property (atomic) BOOL mixpanelWillFlush;

- (void)flushAndWaitForMixpanelQueues;
- (void)waitForMixpanelQueues;
- (void)waitForAsyncQueue;

- (UIViewController *)topViewController;
- (void)assertDefaultPeopleProperties:(NSDictionary *)p;
- (NSDictionary *)allPropertyTypes;

@end
