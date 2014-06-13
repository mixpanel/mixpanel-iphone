//
//  ABTestingTests.m
//  ABTestingTests
//
//  Created by Alex Hofsteede on 12/6/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Mixpanel.h"
#import "MPVariant.h"

#define TEST_TOKEN @"abc123"

@interface MPVariant (Test)
// get access to private members

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onObjects:(NSArray *)objects;

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

@end
