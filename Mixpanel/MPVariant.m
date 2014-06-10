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

+ (void)setValue:(id)value forKey:(NSString *)key onPath:(NSString *)path fromRoot:(UIView *)root
{
    /*NSArray *views = [self getViewsOnPath:path fromRoot:root];
    if ([views count] > 0) {
        for (NSObject *o in views) {
            [o setValue:value forKey:key];
        }
    } else {
        NSLog(@"No objects matching pattern");
    }*/
}

+ (id)convertArg:(id)arg toType:(NSString *)toType
{
    NSString *fromType = [self fromTypeForArg:arg];

    NSString *forwardTransformerName = [NSString stringWithFormat:@"MP%@To%@ValueTransformer", fromType, toType];
    NSValueTransformer *forwardTransformer = [NSValueTransformer valueTransformerForName:forwardTransformerName];
    if (forwardTransformer)
    {
        return [forwardTransformer transformedValue:arg];
    }

    NSString *reverseTransformerName = [NSString stringWithFormat:@"MP%@To%@ValueTransformer", toType, fromType];
    NSValueTransformer *reverseTransformer = [NSValueTransformer valueTransformerForName:reverseTransformerName];
    if (reverseTransformer && [[reverseTransformer class] allowsReverseTransformation])
    {
        return [reverseTransformer reverseTransformedValue:arg];
    }

    NSValueTransformer *defaultTransformer = [NSValueTransformer valueTransformerForName:@"MPPassThroughValueTransformer"];
    return [defaultTransformer reverseTransformedValue:arg];
}

+ (NSString *)fromTypeForArg:(id)arg
{
    NSDictionary *classNameMap = @{@"NSString": [NSString class],
                                   @"NSNumber": [NSNumber class],
                                   @"NSDictionary": [NSDictionary class],
                                   @"NSArray": [NSArray class]};

    NSString *fromType = nil;
    for (NSString *key in classNameMap)
    {
        if ([arg isKindOfClass:classNameMap[key]])
        {
            fromType = key;
            break;
        }
    }
    NSAssert(fromType != nil, @"Expected non-nil fromType!");
    return fromType;
}

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onPath:(MPObjectSelector *)path fromRoot:(NSObject *)root toLeaf:(NSObject *)leaf
{
    if (leaf){
        if ([path isLeafSelected:leaf]) {
            return [self executeSelector:selector withArgs:args onObjects:@[leaf]];
        } else {
            return NO;
        }
    } else {
        return [self executeSelector:selector withArgs:args onObjects:[path selectFromRoot:root]];
    }
}

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onObjects:(NSArray *)objects
{
    BOOL executed = NO;
    if (objects && [objects count] > 0) {
         NSLog(@"Invoking on %lu objects", [objects count]);
        for (NSObject *o in objects) {
            NSMethodSignature *signature = [o methodSignatureForSelector:selector];
            if (signature != nil) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                NSUInteger requiredArgs = [signature numberOfArguments] - 2;
                if ([args count] >= requiredArgs) {
                    [invocation setSelector:selector];
                    for (uint i = 0; i < requiredArgs; i++) {

                        NSArray *argTuple = [args objectAtIndex:i];
                        id arg = [[self class] convertArg:argTuple[0] toType:argTuple[1]];

                        // Unpack NSValues to their base types.
                        if( [arg isKindOfClass:[NSValue class]] ) {
                            const char *ctype = [(NSValue *)arg objCType];
                            NSUInteger size;
                            NSGetSizeAndAlignment(ctype, &size, nil);
                            void *buf = malloc(size);
                            [(NSValue *)arg getValue:buf];
                            [invocation setArgument:(void *)buf atIndex:(int)(i+2)];
                            free(buf);
                        } else {
                            [invocation setArgument:(void *)&arg atIndex:(int)(i+2)];
                        }
                    }
                    @try {
                        NSLog(@"Invoking");
                        [invocation invokeWithTarget:o];
                    }
                    @catch (NSException *exception) {
                        NSLog(@"%@", exception);
                    }
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

        MPObjectSelector *selector = [[MPObjectSelector alloc] initWithString:[action objectForKey:@"path"]];
        void (^executeBlock)(id, SEL, id) = ^(id view, SEL command, id window){

            if ([view isKindOfClass:[UIView class]]){
                CGRect frame = [(UIView *)view frame];
                NSLog(@"%@ %p (%f, %f, %f, %f) with %lu subviews dispatched %@", NSStringFromClass([view class]), view, frame.origin.x, frame.origin.y, frame.size.width, frame.size.height, [[(UIView *)view subviews] count], NSStringFromSelector(command));
            }

            NSLog(@"looking for %@", [action objectForKey:@"path"]);
            NSDate *start = [NSDate date];

            [[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                                 withArgs:[action objectForKey:@"args"]
                                   onPath:selector
                                 fromRoot:[window rootViewController]
                                   toLeaf:view];

            NSDate *finish = [NSDate date];
            NSTimeInterval executionTime = [finish timeIntervalSinceDate:start];
            NSLog(@"selector time = %f", executionTime);
        };

        Class toSwizzle = [selector selectedClass];
        if (!toSwizzle) {
            toSwizzle = [UIView class];
        }
        executeBlock(nil, _cmd, [[UIApplication sharedApplication] keyWindow]);
        [MPSwizzler swizzleSelector:@selector(willMoveToWindow:) onClass:toSwizzle withBlock:executeBlock named:[[NSUUID UUID] UUIDString]];
        //[MPSwizzler unswizzleSelector:@selector(willMoveToWindow:) onClass:[UIView class]];
    }
}

@end
