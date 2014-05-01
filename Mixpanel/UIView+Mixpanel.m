//
//  UIView+Mixpanel.m
//  Mixpanel
//
//  Created by Alex Hofsteede on 30/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>

static IMP __original_Method_Imp;

int _replacement_Method(id self, SEL _cmd, UIWindow *window)
{
    assert([NSStringFromSelector(_cmd) isEqualToString:@"willMoveToWindow:"]);

    // Check for outstanding AB tests for this view here.

    int returnValue = ((int(*)(id, SEL, UIWindow*))__original_Method_Imp)(self, _cmd, window);
    return returnValue + 1;
}

@implementation UIView (Mixpanel)

+ (void)swizzle
{
    Method m = class_getInstanceMethod([self class], @selector(willMoveToWindow:));
    __original_Method_Imp = method_setImplementation(m,(IMP)_replacement_Method);
}

@end
