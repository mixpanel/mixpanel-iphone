//
//  MPSurveyTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelPrivate.h"
#import "MPSurvey.h"
#import "MPSurveyQuestion.h"
#import "MPSurveyNavigationController.h"

@interface MPSurveyTests : MixpanelBaseTests

@end

@implementation MPSurveyTests

- (void)testParseSurveyMissingName {
    NSDictionary *invalid = @{ @"id": @3,
                               @"collections": @[ @{
                                                      @"id": @9
                                                      }
                                                  ],
                               @"questions": @[ @{
                                                    @"id": @12,
                                                    @"type": @"text",
                                                    @"prompt": @"Anything else?",
                                                    @"extra_data": @{}
                                                    }
                                                ]
                               };
    XCTAssertNil([MPSurvey surveyWithJSONObject:invalid]);
}

- (void)testParseSurveyValid {
    XCTAssertNotNil([MPSurvey surveyWithJSONObject:[self validSurveyConfiguration]]);
}

- (void)testParseSurveyNil {
    XCTAssertNil([MPSurvey surveyWithJSONObject:nil]);
}

- (void)testParseSurveyEmpty {
    XCTAssertNil([MPSurvey surveyWithJSONObject:@{}]);
}

- (void)testParseSurveyExtraKeys {
    XCTAssertNil([MPSurvey surveyWithJSONObject:@{@"blah": @"foo"}]);
}

- (NSMutableDictionary *)validSurveyConfiguration {
    return [@{ @"id": @3,
               @"name": @"survey",
               @"collections": @[ @{ @"id": @9,
                                     @"name": @"collection" } ],
               @"questions": @[ @{ @"id": @12,
                                   @"type": @"text",
                                   @"prompt": @"Anything else?",
                                   @"extra_data": @{} } ]
               } mutableCopy];
}

- (void)testParseSurveyInvalidId {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"id"] = @NO;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyInvalidCollections {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"collections"] = @NO;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyEmptyCollections {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"collections"] = @[];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyInvalidCollectionElement {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"collections"] = @[@NO];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyInvalidCollectionElementId {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"collections"] = @[@{@"bo": @"knows"}];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyNoQuestions {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    m[@"questions"] = @[];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyOneInvalidQuestion {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    NSArray *q = @[ @{ @"id": @NO,
                       @"type": @"text",
                       @"prompt": @"Anything else?",
                       @"extra_data": @{}}];
    m[@"questions"] = q;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);
}

- (void)testParseSurveyOneInvalidAndOneValidQuestion {
    NSMutableDictionary *m = [self validSurveyConfiguration];
    NSArray *q = @[ @{ @"id": @NO,
                       @"type": @"text",
                       @"prompt": @"Anything else?",
                       @"extra_data": @{} },
                    @{ @"id": @3,
                       @"type": @"text",
                       @"prompt": @"Anything else?",
                       @"extra_data": @{} }
                    ];
    m[@"questions"] = q;
    
    MPSurvey *s = [MPSurvey surveyWithJSONObject:m];
    XCTAssertNotNil(s);
    XCTAssert(s.questions.count == 1);
}

- (void)testParseSurveyQuestion {
    NSDictionary *o = @{ @"id": @12,
                         @"type": @"text",
                         @"prompt": @"Anything else?",
                         @"extra_data": @{} };
    XCTAssertNotNil([MPSurveyQuestion questionWithJSONObject:o]);
    
    // nil
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:nil]);
    
    // empty
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:@{}]);
    
    // garbage keys
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:@{@"blah": @"foo"}]);
    
    NSMutableDictionary *m;
    
    // invalid id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"id"] = @NO;
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);
    
    // invalid question type
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"type"] = @"not_supported";
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);
    
    // empty prompt
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"prompt"] = @"";
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);
}

- (void)testNoShowSurveyOnPresentingVC {
    NSDictionary *o = @{@"id": @3,
                        @"name": @"survey",
                        @"collections": @[@{@"id": @9, @"name": @"collection"}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};
    
    MPSurvey *survey = [MPSurvey surveyWithJSONObject:o];
    
    //Start presenting a View Controller on the current root
    UIViewController *topViewController = [self topViewController];
    
    __block BOOL waitForBlock = YES;
    [topViewController presentViewController:[[UIViewController alloc]init] animated:YES completion:^{ waitForBlock = NO; }];
    
    //Survey should not show as it cannot present on top of a currently presenting view controller
    [self.mixpanel presentSurveyWithRootViewController:survey];
    
    XCTAssertFalse([[self topViewController] isKindOfClass:[MPSurveyNavigationController class]], @"Survey was presented when it shouldn't have been");
    
    //Wait for original VC to present, so we don't interfere with subsequent tests.
    while(waitForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (void)testShowSurvey {
    NSDictionary *o = @{@"id": @3,
                        @"name": @"survey",
                        @"collections": @[@{@"id": @9, @"name": @"collection"}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};
    
    MPSurvey *survey = [MPSurvey surveyWithJSONObject:o];
    
    [self.mixpanel presentSurveyWithRootViewController:survey];
    UIViewController *topVC = [self topViewController];
    XCTAssertTrue([topVC isKindOfClass:[MPSurveyNavigationController class]], @"Survey was not presented");
    
    // Clean up
    XCTestExpectation *expectation = [self expectationWithDescription:@"survey closed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.mixpanel.currentlyShowingSurvey = nil;
        [(MPSurveyNavigationController *)topVC.presentingViewController dismissViewControllerAnimated:NO completion:^{
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

@end
