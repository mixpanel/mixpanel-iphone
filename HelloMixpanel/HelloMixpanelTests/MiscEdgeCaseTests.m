//
//  MiscEdgeCaseTests.m
//  HelloMixpanel
//
//  Created by Peter Chien on 8/11/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MixpanelBaseTests.h"

@interface MiscEdgeCaseTests : MixpanelBaseTests

@end

@implementation MiscEdgeCaseTests

- (void)testInitializeMixpanelOnBackgroundThread {
    XCTestExpectation *expectation = [self expectationWithDescription:@"main thread checker found no errors"];
    [self tearDownMixpanel];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self setUpMixpanel];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
