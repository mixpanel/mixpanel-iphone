//
//  MPVariant.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPVariant.h"

#import "MPObjectSelector.h"
#import "MPSwizzler.h"

@implementation MPVariant

+ (MPVariant *)variantWithDummyJSONObject {
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"test_variant" withExtension:@"json"]]
                                    options:0 error:nil];
    return [MPVariant variantWithJSONObject:object];
}

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object {

    NSArray *actions = [object objectForKey:@"actions"];
    if (![actions isKindOfClass:[NSArray class]]) {
        NSLog(@"Variant requires an array of actions");
        return nil;
    }

    return [[MPVariant alloc] initWithActions:actions];
}

+ (NSArray *)getViewsOnPath:(NSString *)path fromRoot:(NSObject *)root
{
    MPObjectSelector *selector = [[MPObjectSelector alloc] initWithString:path];
    return [selector selectFromRoot:root];
}

+ (void)setValue:(id)value forKey:(NSString *)key onPath:(NSString *)path fromRoot:(UIView *)root
{
    NSArray *views = [self getViewsOnPath:path fromRoot:root];
    if ([views count] > 0) {
        for (NSObject *o in views) {
            [o setValue:value forKey:key];
        }
    } else {
        NSLog(@"No objects matching pattern");
    }
}

+ (id) convertArg:(id)arg toType:(NSString *)type
{
    NSString *fromType = @"NSString";
    NSString *toTransformerName = [NSString stringWithFormat:@"MP%@To%@ValueTransformer", type, fromType];
    NSValueTransformer *toTransformer = [NSValueTransformer valueTransformerForName:toTransformerName];
    if (!toTransformer) {
        toTransformer = [NSValueTransformer valueTransformerForName:@"MPPassThroughValueTransformer"];
    }

    if (toTransformer && [[toTransformer class] allowsReverseTransformation]) {
        arg = [toTransformer reverseTransformedValue:arg];
    }
    return arg;
}

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onPath:(NSString *)path fromRoot:(NSObject *)root
{
    BOOL executed = NO;
    NSArray *views = [[self class] getViewsOnPath:path fromRoot:root];
    if ([views count] > 0) {
        for (NSObject *o in views) {
            NSMethodSignature *signature = [o methodSignatureForSelector:selector];
            if (signature != nil) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                uint requiredArgs = [signature numberOfArguments] - 2;
                if ([args count] >= requiredArgs) {
                    [invocation setSelector:selector];
                    for (uint i = 0; i < requiredArgs; i++) {

                        NSArray *argTuple = [args objectAtIndex:i];
                        NSObject *arg = [[self class] convertArg:argTuple[0] toType:argTuple[1]];

                        // Unpack NSValues to their base types.
                        if( [arg isKindOfClass:[NSValue class]] ) {
                            void *buf = malloc(sizeof([(NSValue *)arg objCType]));
                            [(NSValue *)arg getValue:buf];
                            [invocation setArgument:(void *)buf atIndex:(int)(i+2)];
                            free(buf);
                        } else {
                            [invocation setArgument:(void *)&arg atIndex:(int)(i+2)];
                        }
                    }
                    [invocation invokeWithTarget:o];
                    executed = YES;
                } else {
                    NSLog(@"Not enough args");
                }
            } else {
                NSLog(@"No selector");
            }
        }
    } else {
        NSLog(@"No objects matching pattern");
    }
    return executed;
}


- (id) initWithActions:(NSArray *)actions
{
    if(self = [super init]) {
        self.actions = actions;
    }
    return self;
}

- (void)execute {
    for (NSDictionary *action in self.actions) {
        BOOL executed = [[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                         withArgs:[action objectForKey:@"args"]
                           onPath:[action objectForKey:@"path"]
                         fromRoot:[[[UIApplication sharedApplication] keyWindow] rootViewController]];
        if (!executed) {
            [MPSwizzler swizzleSelector:@selector(willMoveToWindow:) onClass:[UIView class] withBlock:^{
                NSLog(@"checking if we can execute");
                if ([[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                                     withArgs:[action objectForKey:@"args"]
                                       onPath:[action objectForKey:@"path"]
                                         fromRoot:[[[UIApplication sharedApplication] keyWindow] rootViewController]]) {
                    NSLog(@"executed in swizzle");
                    [MPSwizzler unswizzleSelector:@selector(willMoveToWindow:) onClass:[UIView class]];
                }
            }];
        }
    }
}

@end
