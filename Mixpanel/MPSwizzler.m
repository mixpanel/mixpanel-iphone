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
@property (nonatomic, assign) uint numArgs;
@property (nonatomic, copy) swizzleBlock block;
@end

@implementation MPSwizzle
@end

static NSMapTable *swizzles;

static void mp_swizzledMethod_2(id self, SEL _cmd)
{
    MPSwizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL))swizzle.originalMethod)(self, _cmd);
        swizzle.block(self, _cmd);
    }
}

static void mp_swizzledMethod_3(id self, SEL _cmd, id arg)
{
    MPSwizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);
        swizzle.block(self, _cmd, arg);
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

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)aBlock
{
    MPSwizzle *swizzle = [self swizzleForClass:aClass andSelector:aSelector];
    if (!swizzle) {
        Method m = class_getInstanceMethod(aClass, aSelector);
        uint numArgs = method_getNumberOfArguments(m);
        IMP originalMethod = method_getImplementation(m);
        IMP swizzledMethod = nil;
        if (numArgs == 2) {
            swizzledMethod = (IMP)mp_swizzledMethod_2;
        } else if (numArgs == 3) {
            swizzledMethod = (IMP)mp_swizzledMethod_3;
        }

        if (swizzledMethod) {
            // In the case where we got the Method from the superclass, make sure we actually replace it
            // on this class rather than the superclass.
            if(!class_addMethod(aClass, aSelector, swizzledMethod, method_getTypeEncoding(m))) {
                method_setImplementation(m,swizzledMethod);
            }

            swizzle = [[MPSwizzle alloc] init];
            swizzle.class = aClass;
            swizzle.selector = aSelector;
            swizzle.block = aBlock;
            swizzle.numArgs = numArgs;
            swizzle.originalMethod = originalMethod;

            [self setSwizzle:swizzle forClass:aClass andSelector:aSelector];
        }
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
