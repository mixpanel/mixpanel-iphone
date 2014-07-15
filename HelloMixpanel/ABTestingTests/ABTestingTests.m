//
//  ABTestingTests.m
//  ABTestingTests
//
//  Created by Alex Hofsteede on 12/6/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Mixpanel.h"
#import "MPSwizzler.h"
#import "MPVariant.h"
#import "MPObjectSelector.h"
#import "HomeViewController.h"
#import "HTTPServer.h"
#import "MixpanelDummyDecideConnection.h"

#define TEST_TOKEN @"abc123"

#pragma mark - Interface Redefinitions

@interface Mixpanel (Test)

@property (atomic, copy) NSString *decideURL;
@property (nonatomic, strong) NSSet *variants;

- (void)applicationDidBecomeActive:(NSNotification *)notification;

@end

@interface MPVariantAction (Test)

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onObjects:(NSArray *)objects;

@end

#pragma mark - Test Classes for swizzling

@interface A : NSObject
@property (nonatomic) int count;
- (void)incrementCount;
@end
@implementation A
- (id)init
{
    if((self = [super init])) {
        self.count = 0;
    }
    return self;
}

- (void)incrementCount
{
    self.count += 1;
}
@end

@interface B : A
@end
@implementation B

@end

@interface C : B
@end
@implementation C
- (void)incrementCount
{
    self.count += 2;
}
@end


@interface ABTestingTests : XCTestCase

@property (nonatomic, strong) Mixpanel *mixpanel;
@property (nonatomic, strong) HTTPServer *httpServer;

@end

#pragma mark - Tests

@implementation ABTestingTests

#pragma mark Helper Methods

- (void)setUp {
    [super setUp];
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0];
    self.mixpanel.decideURL = @"http://localhost:31338";
}

- (void)tearDown {
    [super tearDown];
}

- (void)setupHTTPServer
{
    if (!self.httpServer) {
        self.httpServer = [[HTTPServer alloc] init];
        [self.httpServer setConnectionClass:[MixpanelDummyDecideConnection class]];
        [self.httpServer setType:@"_http._tcp."];
        [self.httpServer setPort:31338];

        NSString *webPath = [[NSBundle mainBundle] resourcePath];
        [self.httpServer setDocumentRoot:webPath];

        NSError *error;
        if ([self.httpServer start:&error]) {
            NSLog(@"Started HTTP Server on port %hu", [self.httpServer listeningPort]);
        } else {
            NSLog(@"Error starting HTTP Server: %@", error);
        }
    }
}

-(UIViewController *)topViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

#pragma mark - Invocation and Swizzling
/*
 Test that invocations for various objects work. This includes the parsing and
 deserializing of the selectors and arguments from JSON, apllying to the objects
 and checking that the change was successfully applied.
*/
- (void)testInvocation
{
    UIImageView *imageView = [[UIImageView alloc] init];
    XCTAssert(imageView.image == nil, @"Image should not be set");
    [MPVariantAction executeSelector:@selector(setImage:)
                      withArgs:@[@[@{@"images":@[@{@"scale":@1.0, @"mime_type": @"image/png", @"data":@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0jRW/QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="}]}, @"UIImage"]]
                     onObjects:@[imageView]];
    XCTAssert(imageView.image != nil, @"Image should be set");
    XCTAssertEqual(CGImageGetWidth(imageView.image.CGImage), 1.0f, @"Image should be 1px wide");

    UILabel *label = [[UILabel alloc] init];
    [MPVariantAction executeSelector:@selector(setText:)
                      withArgs:@[@[@"TEST", @"NSString"]]
                     onObjects:@[label]];
    XCTAssertEqualObjects(label.text, @"TEST", @"Label text should be set");

    [MPVariantAction executeSelector:@selector(setTextColor:)
                      withArgs:@[@[@"rgba(108,200,100,0.5)", @"UIColor"]]
                     onObjects:@[label]];
    XCTAssertEqual((int)(CGColorGetComponents(label.textColor.CGColor)[0] * 255), 108, @"Label text color should be set");

    UIButton *button = [[UIButton alloc] init];
    [MPVariantAction executeSelector:@selector(setFrame:)
                      withArgs:@[@[@{@"X":@10,@"Y":@10,@"Width":@10,@"Height":@10}, @"CGRect"]]
                     onObjects:@[button]];
    XCTAssert(button.frame.size.width == 10.0f, @"Button width should be set");
}

/*
 Test that a variant applied application-wide works correctly on existing view objects
 as well as applying the change to new objects as they are added to the view.
*/
- (void)testVariant
{
    // This label added before the Variant is created.
    UILabel *label = [[UILabel alloc] init];
    [label setText:@"Old Text"];
    [[self topViewController].view addSubview:label];

    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"test_variant" withExtension:@"json"]]
                                                           options:0 error:nil];

    MPVariant *variant = [MPVariant variantWithJSONObject:object];
    [variant execute];

    // This label added after the Variant was created.
    UILabel *label2 = [[UILabel alloc] init];
    [label2 setText:@"Old Text 2"];
    [[self topViewController].view addSubview:label2];

    XCTestExpectation *expect = [self expectationWithDescription:@"Text Updated"];
    dispatch_async(dispatch_get_main_queue(), ^{
        XCTAssertEqualObjects(label.text, @"New Text", @"Label text should be set");
        XCTAssertEqualObjects(label2.text, @"New Text", @"Label2 text should be set");
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
    [variant stop];
}

- (void)testStopVariant
{
    // This label added before the Variant is created.
    UILabel *label = [[UILabel alloc] init];
    [label setText:@"Old Text"];
    [[self topViewController].view addSubview:label];

    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"test_variant" withExtension:@"json"]]
                                                           options:0 error:nil];

    MPVariant *variant = [MPVariant variantWithJSONObject:object];
    [variant execute];
    [variant stop];

    // This label added after the Variant was stopped.
    UILabel *label2 = [[UILabel alloc] init];
    [label2 setText:@"Old Text 2"];
    [[self topViewController].view addSubview:label2];

    XCTestExpectation *expect = [self expectationWithDescription:@"Text Updated"];
    dispatch_async(dispatch_get_main_queue(), ^{
        XCTAssertEqualObjects(label.text, @"Old Text", @"Label text should be reverted");
        XCTAssertEqualObjects(label2.text, @"Old Text 2", @"Label2 text should never have changed, as it was added after the variant was stopped");
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testSwizzle
{
    A *a = [[A alloc] init];
    B *b = [[B alloc] init];
    C *c = [[C alloc] init];
    __block int blockCount = 0;

    // Test basic swizzle
    [MPSwizzler swizzleSelector:@selector(incrementCount) onClass:[A class] withBlock:^(id obj, SEL sel){blockCount += 1;} named:@"Swizzle A.incrementProperty"];
    [a incrementCount];
    XCTAssertEqual(a.count, 1, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 1, @"Swizzle on A.incrementCount should have executed");

    // Test swizzle works for objects created after the swizzle was applied
    A *a2 = [[A alloc] init];
    blockCount = 0;
    [a2 incrementCount];
    XCTAssertEqual(a2.count, 1, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 1, @"Swizzle on A.incrementCount should have executed");

    // Test that subclasses without a local definition inherit the swizzled method from the superclass
    blockCount = 0;
    [b incrementCount];
    XCTAssertEqual(b.count, 1, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 1, @"Swizzle A.incrementCount should have executed");

    // Test that a subclasses with with its own method redefinition should not inherit
    // The swizzled method from the superclass.
    blockCount = 0;
    [c incrementCount];
    XCTAssertEqual(c.count, 2, @"Original C.incrementCount should have executed");
    XCTAssertEqual(blockCount, 0, @"Swizzle on A.incrementCount should not have executed when [c incrementCount] was called");

    // Test swizzle on class where superclass has already been swizzled.
    blockCount = 0;
    b.count = 0;
    [MPSwizzler swizzleSelector:@selector(incrementCount) onClass:[B class] withBlock:^(id obj, SEL sel){blockCount += 3;} named:@"Swizzle B.incrementProperty"];
    [b incrementCount];
    XCTAssertEqual(b.count, 1, @"Original B.incrementCount should have executed (inherited function from A)");
    XCTAssertEqual(blockCount, 3, @"Swizzle on B.incrementCount should have executed (but not the swizzle on A.incrementCount");
}

- (void)testUnswizzle
{
    A *a = [[A alloc] init];
    B *b = [[B alloc] init];

    __block int blockCount = 0;
    [MPSwizzler swizzleSelector:@selector(incrementCount) onClass:[A class] withBlock:^(id obj, SEL sel){blockCount += 1;} named:@"Swizzle To Remove"];
    [a incrementCount];
    XCTAssertEqual(a.count, 1, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 1, @"Swizzle on A.incrementCount should have executed");

    blockCount = 0;
    [MPSwizzler unswizzleSelector:@selector(incrementCount) onClass:[A class] named:@"Swizzle To Remove"];
    [a incrementCount];
    XCTAssertEqual(a.count, 2, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 0, @"Swizzle on A.incrementCount should be removed");

    blockCount = 0;
    [b incrementCount];
    XCTAssertEqual(b.count, 1, @"Original A.incrementCount should have executed");
    XCTAssertEqual(blockCount, 0, @"Swizzle on A.incrementCount should be removed");
}

- (void)testSwizzleUI
{
    __block int count = 0;
    [MPSwizzler swizzleSelector:@selector(didMoveToSuperview) onClass:[UIView class] withBlock:^(id obj, SEL sel){count += 1;} named:@"UILabelSwizzle"];
    [[[UIView alloc] init] performSelector:@selector(didMoveToSuperview)];
    XCTAssertEqual(count, 1, @"swizzle should have executed once");

    // Overwrite the same swizzle with a new block
    count = 0;
    [MPSwizzler swizzleSelector:@selector(didMoveToSuperview) onClass:[UIView class] withBlock:^(id obj, SEL sel){count += 2;} named:@"UILabelSwizzle"];
    [[[UIView alloc] init] performSelector:@selector(didMoveToSuperview)];
    XCTAssertEqual(count, 2, @"Swizzle should be 2");

    count = 0;
    [MPSwizzler swizzleSelector:@selector(didMoveToSuperview) onClass:[UIView class] withBlock:^(id obj, SEL sel){count += 1;} named:@"Another swizzle"];
    [[[UIView alloc] init] performSelector:@selector(didMoveToSuperview)];
    XCTAssertEqual(count, 3, @"Both swizzles should have fired, for a total of 3");

}

/*
 Test that swizzling a subclass of a class that has already been swizzled
 does not result in an infinite swizzle stack.
 */
- (void)testSuperSwizzleUI
{
    __block int count = 0;
    [MPSwizzler swizzleSelector:@selector(didMoveToSuperview) onClass:[UIView class] withBlock:^(id obj, SEL sel){count += 1;} named:@"UILabelSwizzle"];
    [MPSwizzler swizzleSelector:@selector(didMoveToSuperview) onClass:[UILabel class] withBlock:^(id obj, SEL sel){count += 2;} named:@"UILabelSwizzle"];

    [[[UIView alloc] init] performSelector:@selector(didMoveToSuperview)];
    XCTAssertEqual(count, 1, @"Only the UIView swizzle should have fired");

    count = 0;
    [[[UILabel alloc] init] performSelector:@selector(didMoveToSuperview)];
    XCTAssertEqual(count, 2, @"Only the UILabel swizzle should have fired");
}

#pragma mark - Decide

- (void)testDecideVariants
{
    [self setupHTTPServer];

    [self.mixpanel identify:@"ABC"];
    XCTestExpectation *expect = [self expectationWithDescription:@"decide requested"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertEqual([MixpanelDummyDecideConnection getRequestCount], 1, @"Decide not queried");
        XCTAssertEqual([self.mixpanel.variants count], (uint)2, @"no variants found");
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

#pragma mark - Object selection

-(void)testObjectSelection
{
    /*
        w___vc___v1___v2___l1
                   \    \__l2
                    \_v3___l3
                        \__l4
     */

    UIWindow *w = [[UIWindow alloc] init];
    UIViewController *vc = [[UIViewController alloc] init];
    UIView *v1 = [[UIView alloc] init];
    UIView *v2 = [[UIView alloc] init];
    UIView *v3 = [[UIView alloc] init];
    UILabel *l1 = [[UILabel alloc] init];
    l1.text = @"Label 1";
    UILabel *l2 = [[UILabel alloc] init];
    l2.text = @"Label 2";
    UILabel *l3 = [[UILabel alloc] init];
    l3.text = @"Label 3";
    UILabel *l4 = [[UILabel alloc] init];
    l4.text = @"Label 4";

    [v2 addSubview:l1];
    [v2 addSubview:l2];
    [v3 addSubview:l3];
    [v3 addSubview:l4];
    [v1 addSubview:v2];
    [v1 addSubview:v3];
    vc.view = v1;
    w.rootViewController = vc;

    // Basic selection
    MPObjectSelector *selector = [MPObjectSelector objectSelectorWithString:@"/UIView/UIView/UILabel"];
    XCTAssert([selector isLeafSelected:l2 fromRoot:vc], @"l2 should be selected from viewcontroller");

    selector = [MPObjectSelector objectSelectorWithString:@"/UIViewController/UIView/UIView/UILabel"];
    XCTAssertEqual([selector selectFromRoot:w][0], l1, @"l1 should be selected from window");

    // Selection by index
    // This selector will get both l2 and l4 as they are the [1]th UILabel in their respective views
    selector = [MPObjectSelector objectSelectorWithString:@"/UIView/UIView/UILabel[1]"];
    XCTAssertEqual([selector selectFromRoot:vc][0], l2, @"l2 should be selected by index");
    XCTAssertEqual([selector selectFromRoot:vc][1], l4, @"l4 should be selected by index");
    XCTAssert([selector isLeafSelected:l2 fromRoot:vc], @"l2 should be selected by index");
    XCTAssert([selector isLeafSelected:l4 fromRoot:vc], @"l4 should be selected by indezx");
    XCTAssertFalse([selector isLeafSelected:l1 fromRoot:vc], @"l1 should not be selected by index");

    // Selection by multiple indexes
    selector = [MPObjectSelector objectSelectorWithString:@"/UIView/UIView[0]/UILabel[1]"];
    XCTAssert([[selector selectFromRoot:vc]containsObject:l2], @"l2 should be selected by index");
    XCTAssertFalse([[selector selectFromRoot:vc] containsObject:l4], @"l4 should not be selected by index");
    XCTAssert([selector isLeafSelected:l2 fromRoot:vc], @"l2 should be selected by index");
    XCTAssertFalse([selector isLeafSelected:l4 fromRoot:vc], @"l4 should be selected by index");
    XCTAssertFalse([selector isLeafSelected:l1 fromRoot:vc], @"l1 should not be selected by index");

    // Invalid index selection (Parent of objects selected by index must be UIViews)
    selector = [MPObjectSelector objectSelectorWithString:@"/UIView[0]/UIView/UILabel"];
    XCTAssertEqual([[selector selectFromRoot:vc] count], (uint)0, @"l2 should be selected by index");

    // Select view by predicate
    selector = [MPObjectSelector objectSelectorWithString:@"/UIView/UIView/UILabel[SELF.text == \"Label 1\"]"];
    XCTAssertEqual([selector selectFromRoot:vc][0], l1, @"l1 should be selected by predicate");
    XCTAssert([selector isLeafSelected:l1 fromRoot:vc], @"l1 should be selected by predicate");
    XCTAssert(![selector isLeafSelected:l2 fromRoot:vc], @"l2 should not be selected by predicate");

}

@end
