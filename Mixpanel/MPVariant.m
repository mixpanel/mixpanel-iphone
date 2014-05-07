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

// For now this is a place to put custom processing for selectors/types that we know
// need a little extra massaging.
+ (id) specialProcessArg:(id)arg atPosition:(int)position forSelector:(SEL)selector
{
    id result = arg;
    if (selector == @selector(setImage:) && position == 0) {
        result = [[UIImage alloc] initWithCGImage:(CGImageRef)arg];
    }
    return result;
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
                        id arg = [[self class] convertArg:argTuple[0] toType:argTuple[1]];
                        arg = [[self class] specialProcessArg:arg atPosition:i forSelector:selector];

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
                if ([[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                                     withArgs:[action objectForKey:@"args"]
                                       onPath:[action objectForKey:@"path"]
                                         fromRoot:[[[UIApplication sharedApplication] keyWindow] rootViewController]]) {
                    [MPSwizzler unswizzleSelector:@selector(willMoveToWindow:) onClass:[UIView class]];
                }

            }];
        }
    }
}

@end
