//
//  MPSwizzler.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import "MPSwizzler.h"

#define MIN_ARGS 2
#define MAX_ARGS 3

@interface MPSwizzle : NSObject
@property (nonatomic, assign) Class class;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP originalMethod;
@property (nonatomic, assign) uint numArgs;
@property (nonatomic, copy) NSMapTable *blocks;
@end

@implementation MPSwizzle

- (id)init
{
    if ((self = [super init])) {
        self.blocks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsObjectPersonality)
                              valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
    }
    return self;
}

@end

static NSMapTable *swizzles;

static void mp_swizzledMethod_2(id self, SEL _cmd)
{
    MPSwizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL))swizzle.originalMethod)(self, _cmd);

        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while((block = [blocks nextObject])) {
            block(self, _cmd);
        }
    }
}

static void mp_swizzledMethod_3(id self, SEL _cmd, id arg)
{
    MPSwizzle *swizzle = [(NSMapTable *)[swizzles objectForKey:[self class]] objectForKey:(__bridge id)((void *)_cmd)];
    if (swizzle) {
        ((void(*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);

        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while((block = [blocks nextObject])) {
            block(self, _cmd);
        }
    }
}

static void (*mp_swizzledMethods[MAX_ARGS - MIN_ARGS + 1])() = {mp_swizzledMethod_2, mp_swizzledMethod_3};

@implementation MPSwizzler

+ (void)load
{
    swizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                     valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
}

+ (void)printSwizzles
{
    NSEnumerator *classEnum = [swizzles keyEnumerator];
    Class class;
    while((class = (Class)[classEnum nextObject])) {
        NSMapTable *selectors = (NSMapTable *)[swizzles objectForKey:class];
        NSEnumerator *selectorEnum = [selectors keyEnumerator];
        SEL selector;
        while((selector = (SEL)((__bridge void *)[selectorEnum nextObject]))) {
            MPSwizzle *swizzle = [self swizzleForClass:class andSelector:selector];
            NSLog(@"%@ %@ %d swizzles", NSStringFromClass(class), NSStringFromSelector(selector), [swizzle.blocks count]);
        }
    }
}

+ (MPSwizzle *)swizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    return [[self swizzledSelectorsForClass:aClass] objectForKey:(__bridge id)((void *)aSelector)];
}

/*
 Gets the swizzle for any swizzled superclasses of this class.
 */
+ (MPSwizzle *)superSwizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    MPSwizzle *swizzle = nil;
    while (swizzle == nil && (aClass = class_getSuperclass(aClass)) != Nil) {
        swizzle = [self swizzleForClass:aClass andSelector:aSelector];
    }
    return swizzle;
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

+ (BOOL)isLocallyDefinedMethod:(Method)aMethod onClass:(Class)aClass
{
    uint count;
    BOOL isLocal = NO;
    Method *methods = class_copyMethodList(aClass, &count);
    for (uint i = 0; i < count; i++) {
        if (aMethod == methods[i]) {
            isLocal = YES;
            break;
        }
    }
    free(methods);
    return isLocal;
}

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)aBlock named:(NSString *)aName
{
    MPSwizzle *swizzle = [self swizzleForClass:aClass andSelector:aSelector];
    if (!swizzle) {
        Method m = class_getInstanceMethod(aClass, aSelector);
        uint numArgs = method_getNumberOfArguments(m);
        if (numArgs >= MIN_ARGS && numArgs <= MAX_ARGS) {
            // If we have already swizzled a superclass of this class, and
            BOOL isLocal = [self isLocallyDefinedMethod:m onClass:aClass];
            MPSwizzle *superSwizzle = [self superSwizzleForClass:aClass andSelector:aSelector];
            IMP originalMethod = (superSwizzle && !isLocal) ? superSwizzle.originalMethod : method_getImplementation(m);
            IMP swizzledMethod = (IMP)mp_swizzledMethods[numArgs - 2];

            if (swizzledMethod) {
                // Either try add a local copy of the method, (if the originalMethod was retrieved from a superclass)
                // or replace the local implementation if it already exists.
                if(!class_addMethod(aClass, aSelector, swizzledMethod, method_getTypeEncoding(m))) {
                    method_setImplementation(m,swizzledMethod);
                }

                swizzle = [[MPSwizzle alloc] init];
                swizzle.class = aClass;
                swizzle.selector = aSelector;
                [swizzle.blocks setObject:aBlock forKey:aName];
                swizzle.numArgs = numArgs;
                swizzle.originalMethod = originalMethod;

                [self setSwizzle:swizzle forClass:aClass andSelector:aSelector];
            }
        }
    } else {
        [swizzle.blocks setObject:aBlock forKey:aName];
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
