//
//  MPCategoryHelpersTests.m
//  MPCategoryHelpersTests
//
//  Created by Amanda Canyon on 11/19/14.
//  Copyright (c) 2014 Amanda Canyon. All rights reserved.
//


#import "MPCategoryHelpers.h"
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface MPCategoryHelpersTests : XCTestCase

@end

@implementation MPCategoryHelpersTests

- (void)testExistence
{
    UIView *v1 = [[UIView alloc] init];
    XCTAssert([v1 respondsToSelector:@selector(mp_varA)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varB)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varC)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varSetD)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varE)]);
    
    XCTAssertFalse([v1 respondsToSelector:@selector(mp_nonexistent)]);
}

- (void)testFingerprinting
{
    NSString *format;
    UIView *v1 = [[UIView alloc] init];
    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(1, 2, 3, 4)];
    l1.text = @"label";
    [v1 addSubview:l1];
    UIButton *b1 = [[UIButton alloc] initWithFrame:CGRectMake(2, 3, 4, 5)];
    [b1 setTitle: @"button" forState:UIControlStateNormal];
    [v1 addSubview:b1];
    UIButton *b2 = [[UIButton alloc] initWithFrame:CGRectMake(20, 30, 40, 50)];
    [b2 setTitle: @"button" forState:UIControlStateNormal];
    [v1 addSubview:b2];
    
    NSString *action = @"signUp";
    NSString *targetAction = [NSString stringWithFormat:@"%lu/%@", UIControlEventTouchUpInside, action];
    [b1 addTarget:self action:NSSelectorFromString(action) forControlEvents:UIControlEventTouchUpInside];
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"checkerboard" withExtension:@"jpg"]]];
    XCTAssert(image);
    [b1 setImage:image forState:UIControlStateNormal];
    
    // mp_targetActions CONTAINS ...
    format = @"mp_varSetD CONTAINS \"ca2e9eeb0bcc438f79c38ffdf5248d8dad4e570c\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    // mp_imageFingerprint
    format = @"mp_varC == \"e38b1eed21994d332fc63b581f7fcbe881bfb1f7\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    format = @"mp_fingerprintVersion == 1 AND mp_varE = \"e0db845a9917b9139c63182c948ac91a5e86b485\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    // Predicates with invalid properties
    format = @"mp_nonexistent = 123";
    XCTAssertThrowsSpecificNamed([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1], NSException, @"NSUnknownKeyException");
}

- (void)testImageFingerprint
{
    UIButton *b1 = [[UIButton alloc] init];
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"huge_checkerboard" withExtension:@"jpg"]]];
    XCTAssert(image);
    [b1 setImage:image forState:UIControlStateNormal];
    UIButton *b2 = [[UIButton alloc] init];
    image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"small_checkerboard" withExtension:@"jpg"]]];
    XCTAssert(image);
    [b2 setImage:image forState:UIControlStateNormal];
    
    XCTAssertEqualObjects([b1 performSelector:NSSelectorFromString(@"mp_varC")], [b2 performSelector:NSSelectorFromString(@"mp_varC")]);
}


@end