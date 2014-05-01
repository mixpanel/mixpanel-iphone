//
//  MPSwizzler.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import "MPSwizzler.h"

#pragma message("TODO: We need one of these for every pair of class/selector we want to swizzle")
static IMP __original_Method_Imp;

void mp_swizzledMethod(id self, SEL _cmd, UIWindow *window)
{
    assert([NSStringFromSelector(_cmd) isEqualToString:@"willMoveToWindow:"]);

    NSLog(@"I'm in ur view!");
    // Check for outstanding AB tests for this view here.

    ((void(*)(id, SEL, UIWindow*))__original_Method_Imp)(self, _cmd, window);
}

@implementation MPSwizzler

+ (void)swizzleSelector:(SEL)selector onClass:(Class)class
{
    if (!__original_Method_Imp) {
        Method m = class_getInstanceMethod(class, selector);
        __original_Method_Imp = method_getImplementation(m);

        // In the case where we got the Method from the superclass, make sure we actually replace it
        // on this class rather than the superclass.
        if(!class_addMethod(class, selector, (IMP)mp_swizzledMethod, method_getTypeEncoding(m))) {
            method_setImplementation(m,(IMP)mp_swizzledMethod);
        }
    }
}

+ (void)unswizzleSelector:(SEL)selector onClass:(Class)class
{
    if (__original_Method_Imp) {
        Method m = class_getInstanceMethod(class, selector);
        __original_Method_Imp = method_setImplementation(m, __original_Method_Imp);
        __original_Method_Imp = nil;
    }
}

@end
