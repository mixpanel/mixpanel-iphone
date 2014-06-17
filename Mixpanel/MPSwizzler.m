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
    Method aMethod = class_getInstanceMethod([self class], _cmd);
    MPSwizzle *swizzle = (MPSwizzle *)[swizzles objectForKey:(__bridge id)((void *)aMethod)];
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
    Method aMethod = class_getInstanceMethod([self class], _cmd);
    MPSwizzle *swizzle = (MPSwizzle *)[swizzles objectForKey:(__bridge id)((void *)aMethod)];
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
    NSEnumerator *en = [swizzles objectEnumerator];
    MPSwizzle *swizzle;
    while((swizzle = (MPSwizzle *)[en nextObject])) {
        NSLog(@"%@ %@ %d swizzles", NSStringFromClass(swizzle.class), NSStringFromSelector(swizzle.selector), [swizzle.blocks count]);
    }
}

+ (MPSwizzle *)swizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    if (aMethod != NULL) {
        return [self swizzleForMethod:aMethod];
    }
    return nil;
}

+ (MPSwizzle *)swizzleForMethod:(Method)aMethod
{
    return (MPSwizzle *)[swizzles objectForKey:(__bridge id)((void *)aMethod)];
}

/*
 Gets the swizzle for any swizzled superclasses of this class.
 */
/*+ (MPSwizzle *)superSwizzleForClass:(Class)aClass andSelector:(SEL)aSelector
{
    MPSwizzle *swizzle = nil;
    while (swizzle == nil && (aClass = class_getSuperclass(aClass)) != Nil) {
        Method aMethod = class_getInstanceMethod(aClass, aSelector);
        if ([self isLocallyDefinedMethod:aMethod onClass:aClass]) {
            swizzle = [self swizzleForMethod:aMethod];
        }
    }
    return swizzle;
}*/

+ (void)removeSwizzleForMethod:(Method)aMethod
{
    [swizzles removeObjectForKey:(__bridge id)((void *)aMethod)];
}

+ (void)setSwizzle:(MPSwizzle *)swizzle forMethod:(Method)aMethod
{
    [swizzles setObject:swizzle forKey:(__bridge id)((void *)aMethod)];
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
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    uint numArgs = method_getNumberOfArguments(aMethod);
    if (numArgs >= MIN_ARGS && numArgs <= MAX_ARGS) {

        BOOL isLocal = [self isLocallyDefinedMethod:aMethod onClass:aClass];
        IMP swizzledMethod = (IMP)mp_swizzledMethods[numArgs - 2];
        MPSwizzle *swizzle = [self swizzleForMethod:aMethod];

        if (isLocal) {
            if (!swizzle) {
                IMP originalMethod = method_getImplementation(aMethod);

                // Replace the local implementation of this method with the swizzled one
                method_setImplementation(aMethod,swizzledMethod);

                swizzle = [[MPSwizzle alloc] init];
                swizzle.class = aClass;
                swizzle.selector = aSelector;
                [swizzle.blocks setObject:aBlock forKey:aName];
                swizzle.numArgs = numArgs;
                swizzle.originalMethod = originalMethod;

                [self setSwizzle:swizzle forMethod:aMethod];

            } else {
                [swizzle.blocks setObject:aBlock forKey:aName];
            }
        } else {
            IMP originalMethod = swizzle ? swizzle.originalMethod : method_getImplementation(aMethod);

            MPSwizzle *newSwizzle = [[MPSwizzle alloc] init];
            newSwizzle.class = aClass;
            newSwizzle.selector = aSelector;
            [newSwizzle.blocks setObject:aBlock forKey:aName];
            newSwizzle.numArgs = numArgs;
            newSwizzle.originalMethod = originalMethod;

            // Add the swizzle as a new local method on the class.
            if (!class_addMethod(aClass, aSelector, swizzledMethod, method_getTypeEncoding(aMethod))) {
                [NSException raise:@"SwizzleException" format:@"Could not add swizzled method %@, even though it didn't already exist locally", newSwizzle];
            }
            // Now re-get the Method, it should be the one we just added.
            Method newMethod = class_getInstanceMethod(aClass, aSelector);
            if (aMethod == newMethod) {
                [NSException raise:@"SwizzleException" format:@"Newly added method was the same as the old method: %@", newSwizzle];
            }
            [self setSwizzle:newSwizzle forMethod:newMethod];
        }
    } else {
        [NSException raise:@"SwizzleException" format:@"Cannot swizzle method with %d args", numArgs];
    }
}

+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass
{
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    MPSwizzle *swizzle = [self swizzleForMethod:aMethod];
    if (swizzle) {
        method_setImplementation(aMethod, swizzle.originalMethod);
        [self removeSwizzleForMethod:aMethod];
    }
}

@end
