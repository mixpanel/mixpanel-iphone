//
//  MPSwizzler.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import "MPSwizzler.h"

@interface MPSwizzle : NSObject
@property (nonatomic, assign) Class class;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP originalMethod;
@property (nonatomic, copy) void (^block)(id);
@end

@implementation MPSwizzle
@end

static NSMapTable *swizzles;

static void mp_swizzledMethod(id self, SEL _cmd, id arg)
{
    MPSwizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);
        swizzle.block(arg);
    }
}

@implementation MPSwizzler

+ (void)load
{
    swizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                     valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
}

+ (MPSwizzle *)swizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    return [[self swizzledSelectorsForClass:aClass] objectForKey:(__bridge id)((void *)aSelector)];
}

+ (NSMapTable *)swizzledSelectorsForClass:(Class)aClass
{
    return (NSMapTable *)[swizzles objectForKey:aClass];
}

+ (void)removeSwizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    NSMapTable *selectors = [self swizzledSelectorsForClass:aClass];
    if (selectors)
    {
        [selectors removeObjectForKey:(__bridge id)((void *)aSelector)];
    }
}

+ (void)setSwizzle:(MPSwizzle *)swizzle forClass:(Class)aClass andSelector:(SEL)aSelector
{
    NSMapTable *selectors = [self swizzledSelectorsForClass:aClass];
    if (!selectors) {
        selectors = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                          valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
        [swizzles setObject:selectors forKey:aClass];
    }

    [selectors setObject:swizzle forKey:(__bridge id)((void *)aSelector)];
}

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(void (^)(id))block
{
    MPSwizzle *swizzle = [self swizzleForClass:aClass andSelector:aSelector];
    if (!swizzle) {
        Method m = class_getInstanceMethod(aClass, aSelector);
        IMP originalMethod = method_getImplementation(m);

        // In the case where we got the Method from the superclass, make sure we actually replace it
        // on this class rather than the superclass.
        if(!class_addMethod(aClass, aSelector, (IMP)mp_swizzledMethod, method_getTypeEncoding(m))) {
            method_setImplementation(m,(IMP)mp_swizzledMethod);
        }

        swizzle = [[MPSwizzle alloc] init];
        swizzle.class = aClass;
        swizzle.selector = aSelector;
        swizzle.block = block;
        swizzle.originalMethod = originalMethod;

        [self setSwizzle:swizzle forClass:aClass andSelector:aSelector];
    }
}

+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass
{
    MPSwizzle *swizzle = [self swizzleForClass:aClass andSelector:aSelector];
    if (swizzle) {
        Method m = class_getInstanceMethod(aClass, aSelector);
        method_setImplementation(m, swizzle.originalMethod);
        [self removeSwizzleForClass:aClass andSelector:aSelector];
    }
}

@end
