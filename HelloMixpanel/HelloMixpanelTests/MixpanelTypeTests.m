//
//  MPValueTests.m
//  HelloMixpanel
//
//  Created by Weizhe Yuan on 9/6/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelType.h"
#import <Foundation/Foundation.h>
@interface MixpanelTypeTests : MixpanelBaseTests

@end

// only used for equality test
@interface DummyType : NSObject
@end

@implementation DummyType
- (BOOL)isEqual:(id)object
{
    return YES;
}
@end

@implementation MixpanelTypeTests

- (void)testEqualString
{
    XCTAssertFalse([@"foo" equalToMixpanelType:@"bar"]);
    XCTAssertTrue([@"foo" equalToMixpanelType:@"foo"]);
}

- (void)testEqualNumber
{
    XCTAssertTrue([@1.5 equalToMixpanelType:@1.5]);
    XCTAssertTrue([@1 equalToMixpanelType:@1]);
    XCTAssertTrue([@1 equalToMixpanelType:@1.0]);
    XCTAssertFalse([@1 equalToMixpanelType:@1.5]);
}

- (void)testDifferentTypes
{
    XCTAssertFalse([@1 equalToMixpanelType:@"foo"]);
    XCTAssertFalse([@"foo" equalToMixpanelType:@1]);
}

- (void)testEqualArrayBasic
{
    XCTAssertTrue([@[] equalToMixpanelType:@[]]);
    XCTAssertTrue([@[ @1 ] equalToMixpanelType:@[ @1 ]]);
}

- (void)testSubArrayNotEqual
{
    NSArray *a = @[ @1, @2 ];
    NSArray *b = @[ @1 ];
    XCTAssertFalse([a equalToMixpanelType:b]);
    XCTAssertFalse([b equalToMixpanelType:a]);
}

- (void)testShuffledArrayNotEqual
{
    NSArray *a = @[ @1, @2 ];
    NSArray *b = @[ @2, @1 ];
    XCTAssertFalse([a equalToMixpanelType:b]);
}

- (void)testEqualDictionaryBasic
{
    NSDictionary *a = @{@"foo" : @1, @"bar" : @2};
    NSDictionary *b = @{@"bar" : @2, @"foo" : @1};
    XCTAssertTrue([a equalToMixpanelType:b]);
    XCTAssertTrue([@{} equalToMixpanelType:@{}]);
}

- (void)testEqualDictionaryDifferentValues
{
    NSDictionary *a = @{@"foo" : @1, @"bar" : @1};
    NSDictionary *b = @{@"bar" : @2, @"foo" : @1};
    XCTAssertFalse([a equalToMixpanelType:b]);
}

- (void)testDictionaryWithDifferentKeys
{
    NSDictionary *a = @{@"foo" : @1, @"bar1" : @1};
    NSDictionary *b = @{@"foo" : @1, @"bar2" : @1};
    XCTAssertFalse([a equalToMixpanelType:b]);
}

- (void)testEqualDictionarySubset
{
    NSDictionary *a = @{@"foo" : @1};
    NSDictionary *b = @{@"foo" : @1, @"bar" : @1};
    XCTAssertFalse([a equalToMixpanelType:b]);
    XCTAssertFalse([b equalToMixpanelType:a]);
}

- (void)testNonMixpanelTypeShouldNotEqual
{
    DummyType *a = [[DummyType alloc] init];
    DummyType *b = [[DummyType alloc] init];
    NSArray *lhs = @[ a ];
    NSArray *rhs = @[ b ];
    XCTAssertFalse([lhs equalToMixpanelType:rhs]);
    XCTAssertTrue([a isEqual:b]);
}

- (void)testNestedDictionary
{
    NSDictionary *a = @{@"foo" : @{@"bar" : @1}};
    NSDictionary *b = @{@"foo" : @{@"bar" : @1}};
    XCTAssertTrue([a equalToMixpanelType:b]);
}

- (void)testNestedDictionaryWithNonMixpanelTypeKey
{
    DummyType *d = [[DummyType alloc] init];
    NSDictionary *a = @{@"foo" : @{@"bar" : d}};
    NSDictionary *b = @{@"foo" : @{@"bar" : d}};
    XCTAssertFalse([a equalToMixpanelType:b]);
}

@end
