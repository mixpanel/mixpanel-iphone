//
//  MPCategoryHelpersTests.m
//  MPCategoryHelpersTests
//
//  Created by Amanda Canyon on 11/19/14.
//  Copyright (c) 2014 Amanda Canyon. All rights reserved.
//

#import "UIView+MPHelpers.h"
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface UIView (MPCategoryHelpersTests)

- (NSString *)mp_imageFingerprint;
- (NSString *)mp_viewId;
- (NSString *)mp_controllerVariable;

- (NSString *)mp_varC;

@end

@interface MPCategoryHelpersTests : XCTestCase

@end

@implementation MPCategoryHelpersTests

- (void)testControllerVariableNil {
    UIView *v1 = [[UIView alloc] init];
    
    NSString *v2 = [v1 mp_controllerVariable];
    XCTAssertNil(v2);
}

- (void)testControllerVariableDefault {
    UIViewController *v1 = [[UIViewController alloc] init];
    
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [v1.view addSubview:b];
    
    NSString *v2 = [b mp_controllerVariable];
    XCTAssertNil(v2);
}

- (void)testExistence {
    UIView *v1 = [[UIView alloc] init];
    
    XCTAssert([v1 respondsToSelector:@selector(mp_viewId)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_controllerVariable)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_imageFingerprint)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_imageFingerprint)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_text)]);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    XCTAssertFalse([v1 respondsToSelector:@selector(mp_nonexistent)]);
#pragma clang diagnostic pop
}

- (void)testExistenceLegacy {
    UIView *v1 = [[UIView alloc] init];
    
    XCTAssert([v1 respondsToSelector:@selector(mp_varA)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varB)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varC)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varSetD)]);
    XCTAssert([v1 respondsToSelector:@selector(mp_varE)]);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    XCTAssertFalse([v1 respondsToSelector:@selector(mp_nonexistent)]);
#pragma clang diagnostic pop
}

- (void)testFingerprinting {
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
    
    [b1 addTarget:self
           action:@selector(signUp)
 forControlEvents:UIControlEventTouchUpInside];
    
    UIImage *image = [MPCategoryHelpersTests imageNamed:@"checkerboard"];
    XCTAssert(image);
    [b1 setImage:image forState:UIControlStateNormal];
    
    // Legacy
    format = @"mp_varSetD CONTAINS \"ca2e9eeb0bcc438f79c38ffdf5248d8dad4e570c\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    // Legacy
    format = @"mp_varC == \"e38b1eed21994d332fc63b581f7fcbe881bfb1f7\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    // Legacy
    format = @"mp_fingerprintVersion == 1 AND mp_varE = \"e0db845a9917b9139c63182c948ac91a5e86b485\"";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    
    // Predicates with invalid properties
    format = @"mp_nonexistent = 123";
    XCTAssertThrowsSpecificNamed([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1],
                                 NSException, @"NSUnknownKeyException");
}

- (void)testTextCategoryLabel {
    UILabel *l = [[UILabel alloc] init];
    l.text = @"asdf";
    XCTAssertEqualObjects([l mp_text], @"asdf");
}

- (void)testTextCategoryButton {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:@"asdf" forState:UIControlStateNormal];
    XCTAssertEqualObjects([b mp_text], @"asdf");
}

- (void)testImageFingerprintTabBarButton {
    UITabBar *tabBar = [[UITabBar alloc] init];
    tabBar.items = @[ [[UITabBarItem alloc] initWithTitle:@"Checker"
                                                    image:[MPCategoryHelpersTests imageNamed:@"checkerboard"]
                                                      tag:0]  ];
    id /* UITabBarSwappableImageView */ v = tabBar.subviews.firstObject.subviews.firstObject;
    XCTAssertEqualObjects([v mp_imageFingerprint], @"8fHx8R8fHx/x8fHxHx8fH/Hx8fEfHx8f8fHx8R8fHx8=");
}

- (void)testImageFingerprintButton {
    UIButton *b1 = [[UIButton alloc] init];
    UIImage *image = [MPCategoryHelpersTests imageNamed:@"huge_checkerboard"];
    XCTAssert(image);
    [b1 setImage:image forState:UIControlStateNormal];
    
    UIButton *b2 = [[UIButton alloc] init];
    image = [MPCategoryHelpersTests imageNamed:@"small_checkerboard"];
    XCTAssert(image);
    [b2 setImage:image forState:UIControlStateNormal];
    
    XCTAssertEqualObjects([b1 mp_imageFingerprint], [b2 mp_imageFingerprint]);
    XCTAssertEqualObjects([b1 mp_varC], [b2 mp_varC]);
}

+ (UIImage *)imageNamed:(NSString *)name {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSURL *URL = [testBundle URLForResource:name
                              withExtension:@"jpg"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    return [UIImage imageWithData:data];
}

@end
