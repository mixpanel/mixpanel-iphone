//
//  MPSwizzler.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import "MPSwizzler.h"

@interface Swizzle : NSObject
@property (nonatomic, assign) Class class;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP originalMethod;
@property (nonatomic, copy) void (^block)(id);
@end

@implementation Swizzle
@end

static NSMapTable *swizzles;

static void mp_swizzledMethod(id self, SEL _cmd, id arg)
{
    Swizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);
        swizzle.block(arg);
    }
}

@implementation MPSwizzler

+(void)load
{
    swizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                     valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
}

+ (Swizzle *)getSwizzleForClass:(Class)class andSelector:(SEL)selector
{
    return [(NSMapTable *)[swizzles objectForKey:class] objectForKey:(__bridge id)((void *)selector)];
}

+ (void)setSwizzle:(Swizzle *)swizzle forClass:(Class)class andSelector:(SEL)selector
{
    NSMapTable *selectors = [swizzles objectForKey:class];
    if (!selectors) {
        selectors = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                          valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
        [swizzles setObject:selectors forKey:class];
    }
    [selectors setObject:swizzle forKey:(__bridge id)((void *)selector)];
}

+ (void)swizzleSelector:(SEL)selector onClass:(Class)class withBlock:(void (^)(id))block
{
    Swizzle *swizzle = [self getSwizzleForClass:class andSelector:selector];
    if (!swizzle) {
        Method m = class_getInstanceMethod(class, selector);
        IMP originalMethod = method_getImplementation(m);

        // In the case where we got the Method from the superclass, make sure we actually replace it
        // on this class rather than the superclass.
        if(!class_addMethod(class, selector, (IMP)mp_swizzledMethod, method_getTypeEncoding(m))) {
            method_setImplementation(m,(IMP)mp_swizzledMethod);
        }

        swizzle = [[Swizzle alloc] init];
        swizzle.class = class;
        swizzle.selector = selector;
        swizzle.block = block;
        swizzle.originalMethod = originalMethod;
        [self setSwizzle:swizzle forClass:class andSelector:selector];
    }
}

+ (void)unswizzleSelector:(SEL)selector onClass:(Class)class
{
    Swizzle *swizzle = [self getSwizzleForClass:class andSelector:selector];
    if (swizzle) {
        Method m = class_getInstanceMethod(class, selector);
        method_setImplementation(m, swizzle.originalMethod);
        [swizzles removeObjectForKey:class];
    }
}

@end
