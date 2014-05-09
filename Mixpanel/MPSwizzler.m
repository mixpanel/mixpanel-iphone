//
//  MPSwizzler.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import "MPSwizzler.h"

//static IMP _originalMethod;
//static void (^_block)(void);

@interface Swizzle : NSObject

@property (nonatomic, assign)Class class;
@property (nonatomic, assign)SEL selector;
@property (nonatomic, assign)IMP originalMethod;
@property (nonatomic, strong)void (^block)(void);

@end

@implementation Swizzle

@end

static NSMapTable *swizzles;

static void mp_swizzledMethod(id self, SEL _cmd, ...)
{
    Swizzle *swizzle = [swizzles objectForKey:[self class]];

    // Call the original function with the args we were given.
    va_list argp;
    va_start(argp, _cmd);
    ((void(*)(id, SEL, ...))swizzle.originalMethod)(self, _cmd, argp);
    va_end(argp);

    // Call the swizzle block
    swizzle.block();
}

@implementation MPSwizzler

+(void)load
{
    swizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory) valueOptions:(NSPointerFunctionsStrongMemory)];
}

+ (Swizzle *)getSwizzleForClass:(Class)class andSelector:(SEL)selector
{
    return [swizzles objectForKey:class];
}

+ (void)setSwizzle:(Swizzle *)swizzle forClass:(Class)class andSelector:(SEL)selector
{
    [swizzles setObject:swizzle forKey:class];
}

+ (void)swizzleSelector:(SEL)selector onClass:(Class)class withBlock:(void (^)(void))block
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
