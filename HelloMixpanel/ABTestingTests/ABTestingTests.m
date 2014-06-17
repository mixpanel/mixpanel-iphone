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
#import "HomeViewController.h"

#define TEST_TOKEN @"abc123"

@interface MPVariant (Test)
// get access to private members

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onObjects:(NSArray *)objects;

@end

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

@end

@implementation ABTestingTests

- (void)setUp {
    [super setUp];
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testVariantInvocation
{
    UIImageView *imageView = [[UIImageView alloc] init];
    XCTAssert(imageView.image == nil, @"Image should not be set");
    [MPVariant executeSelector:@selector(setImage:)
                      withArgs:@[@[@{@"images":@[@{@"scale":@1.0, @"mime_type": @"image/png", @"data":@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0jRW/QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="}]}, @"UIImage"]]
                     onObjects:@[imageView]];
    XCTAssert(imageView.image != nil, @"Image should be set");
    XCTAssertEqual(CGImageGetWidth(imageView.image.CGImage), 1.0f, @"Image should be 1px wide");

    UILabel *label = [[UILabel alloc] init];
    [MPVariant executeSelector:@selector(setText:)
                      withArgs:@[@[@"TEST", @"NSString"]]
                     onObjects:@[label]];
    XCTAssertEqualObjects(label.text, @"TEST", @"Label text should be set");

    [MPVariant executeSelector:@selector(setTextColor:)
                      withArgs:@[@[@"rgba(101,200,100,0.5)", @"UIColor"]]
                     onObjects:@[label]];
    XCTAssert(CGColorGetComponents(label.textColor.CGColor)[0] * 255 == 101.0f, @"Label text color should be set");

    UIButton *button = [[UIButton alloc] init];
    [MPVariant executeSelector:@selector(setFrame:)
                      withArgs:@[@[@{@"X":@10,@"Y":@10,@"Width":@10,@"Height":@10}, @"CGRect"]]
                     onObjects:@[button]];
    XCTAssert(button.frame.size.width == 10.0f, @"Button width should be set");
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
    //XCTAssertEqual(b.count, 1, @"Original A.incrementCount should have executed");
    //XCTAssertEqual(blockCount, 1, @"Swizzle A.incrementCount should have executed");

    // Test that a subclasses with with its own method redefinition should not inherit
    // The swizzled method from the superclass.
    blockCount = 0;
    [c incrementCount];
    XCTAssertEqual(c.count, 2, @"Original C.incrementCount should have executed");
    XCTAssertEqual(blockCount, 0, @"Swizzle on A.incrementCount should not have executed when [c incrementCount] was called");

    // Test swizzle on class where superclass has already been swizzled.
    blockCount = 0;
    [MPSwizzler swizzleSelector:@selector(incrementCount) onClass:[B class] withBlock:^(id obj, SEL sel){blockCount += 3;} named:@"Swizzle B.incrementProperty"];
    [b incrementCount];
    XCTAssertEqual(b.count, 1, @"Original B.incrementCount should have executed (inherited function from A)");
    XCTAssertEqual(blockCount, 3, @"Swizzle on B.incrementCount should have executed (but not the swizzle on A.incrementCount");
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

@end
