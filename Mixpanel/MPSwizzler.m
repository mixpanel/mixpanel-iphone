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
static IMP _originalMethod;
static void (^_block)();

void mp_swizzledMethod(id self, SEL _cmd, UIWindow *window )
{
    NSLog(@"Running swizzled method");
    assert([NSStringFromSelector(_cmd) isEqualToString:@"willMoveToWindow:"]);

    ((void(*)(id, SEL, UIWindow*))_originalMethod)(self, _cmd, window);

    _block();

}

@implementation MPSwizzler

+ (void)swizzleSelector:(SEL)selector onClass:(Class)class withBlock:(void (^)())block
{
    if (!_originalMethod) {
        Method m = class_getInstanceMethod(class, selector);
        _originalMethod = method_getImplementation(m);
        _block = block;

        // In the case where we got the Method from the superclass, make sure we actually replace it
        // on this class rather than the superclass.
        if(!class_addMethod(class, selector, (IMP)mp_swizzledMethod, method_getTypeEncoding(m))) {
            method_setImplementation(m,(IMP)mp_swizzledMethod);
        }
    }
}

+ (void)unswizzleSelector:(SEL)selector onClass:(Class)class
{
    if (_originalMethod) {
        Method m = class_getInstanceMethod(class, selector);
        _originalMethod = method_setImplementation(m, _originalMethod);
        _originalMethod = nil;
        _block = nil;
    }
}

@end
