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

#pragma mark -- Constructing Variants

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object {

    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && [ID integerValue] > 0)) {
        NSLog(@"invalid variant id: %@", ID);
        return nil;
    }

    NSNumber *experimentID = object[@"experiment_id"];
    if (!([experimentID isKindOfClass:[NSNumber class]] && [experimentID integerValue] > 0)) {
        NSLog(@"invalid experiment id: %@", experimentID);
        return nil;
    }

    NSArray *actions = [object objectForKey:@"actions"];
    if (![actions isKindOfClass:[NSArray class]]) {
        NSLog(@"variant requires an array of actions");
        return nil;
    }

    return [[MPVariant alloc] initWithID:[ID unsignedIntegerValue]
                            experimentID:[experimentID unsignedIntegerValue]
                              andActions:actions];
}

- (id) initWithID:(NSUInteger)ID experimentID:(NSUInteger)experimentID andActions:(NSArray *)actions
{
    if(self = [super init]) {
        self.ID = ID;
        self.experimentID = experimentID;
        self.actions = [NSMutableArray array];
        [self addActions:actions andExecute:NO];
    }
    return self;
}

- (void) addActions:(NSArray *)actions andExecute:(BOOL)exec
{
    for (NSDictionary *action in actions) {
        [self addAction:action andExecute:exec];
    }
}

- (void) addAction:(NSDictionary *)action andExecute:(BOOL)exec
{
    [self.actions addObject:action];
    if (exec) {
        [self executeAction:action];
    }
}

- (void)removeAction:(NSDictionary *)action
{
    if([action valueForKey:@"name"]) {
        for (NSDictionary *a in self.actions) {
            if([[action objectForKey:@"name"] isEqualToString:[a objectForKey:@"name"]]) {
                [self.actions removeObjectIdenticalTo:a];
                break;
            }
        }
    }
}

+ (Class)getSwizzleClassFromAction:(NSDictionary *)action andPath:(MPObjectSelector *)path
{
    Class swizzleClass;
    if ([action objectForKey:@"swizzleClass"]) {
        swizzleClass = NSClassFromString([action objectForKey:@"swizzleClass"]);
    }
    if (!swizzleClass) {
        swizzleClass = [path selectedClass];
    }
    if (!swizzleClass) {
        swizzleClass = [UIView class];
    }
    return swizzleClass;
}

+ (SEL)getSwizzleSelectorFromAction:(NSDictionary *)action
{
    SEL swizzleSelector = nil;
    if ([action objectForKey:@"swizzleSelector"]) {
        swizzleSelector = NSSelectorFromString([action objectForKey:@"swizzleSelector"]);
    }
    if (!swizzleSelector) {
        swizzleSelector = @selector(didMoveToWindow);
    }
    return swizzleSelector;
}

+ (NSString *)getSwizzleNameFromAction:(NSDictionary *)action
{
    NSString *name;
    if ([action objectForKey:@"name"]) {
        name = [action objectForKey:@"name"];
    } else {
        name = [[NSUUID UUID] UUIDString];
    }
    return name;
}

#pragma mark -- Executing Variant actions

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

+ (BOOL)setValue:(id)value forKey:(NSString *)key onPath:(MPObjectSelector *)path fromRoot:(UIView *)root toLeaf:(NSObject *)leaf
{
    if (leaf){
        if ([path isLeafSelected:leaf fromRoot:root]) {
            return [self setValue:value forKey:key onObjects:@[leaf]];
        } else {
            return NO;
        }
    } else {
        return [self setValue:value forKey:key onObjects:[path selectFromRoot:root]];
    }
}

+ (BOOL)setValue:(id)value forKey:(NSString *)key onObjects:(NSArray *)objects
{
    if ([objects count] > 0) {
        for (NSObject *o in objects) {
            [o setValue:value forKey:key];
        }
        return YES;
    } else {
        NSLog(@"No objects matching pattern");
        return NO;
    }
}

+ (BOOL)executeSelector:(SEL)selector withArgs:(NSArray *)args onPath:(MPObjectSelector *)path fromRoot:(NSObject *)root toLeaf:(NSObject *)leaf
{
    NSLog(@"Looking for objects matching %@ on path from %@ to %@", path, [root class], [leaf class]);
    if (leaf){
        if ([path isLeafSelected:leaf fromRoot:root]) {
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
         NSLog(@"Invoking on %d objects", [objects count]);
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

- (void)execute {
    for (NSDictionary *action in self.actions) {
        [self executeAction:action];
    }
}

- (void)executeAction:(NSDictionary *)action
{
    MPObjectSelector *path = [MPObjectSelector objectSelectorWithString:[action objectForKey:@"path"]];

    // Block to execute on swizzle
    void (^executeBlock)(id, SEL) = ^(id view, SEL command){
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self class] executeSelector:NSSelectorFromString([action objectForKey:@"selector"])
                                 withArgs:[action objectForKey:@"args"]
                                   onPath:path
                                 fromRoot:[[UIApplication sharedApplication] keyWindow].rootViewController
                                   toLeaf:view];
        });
    };

    // Execute once in case the view to be changed is already on screen.
    executeBlock(nil, _cmd);

    if (![action objectForKey:@"swizzle"] || [[action objectForKey:@"swizzle"] boolValue]) {
        // Swizzle the method needed to check for this object coming onscreen
        [MPSwizzler swizzleSelector:[MPVariant getSwizzleSelectorFromAction:action]
                            onClass:[MPVariant getSwizzleClassFromAction:action andPath:path]
                          withBlock:executeBlock
                              named:[MPVariant getSwizzleNameFromAction:action]];
        [MPSwizzler printSwizzles];
    }
}

- (void)stop {
    for (NSDictionary *action in self.actions) {
        [self stopAction:action];
    }
}

- (void)stopAction:(NSDictionary *)action
{
    MPObjectSelector *path = [MPObjectSelector objectSelectorWithString:[action objectForKey:@"path"]];
    [MPSwizzler unswizzleSelector:[MPVariant getSwizzleSelectorFromAction:action]
                          onClass:[MPVariant getSwizzleClassFromAction:action andPath:path]
                            named:[MPVariant getSwizzleNameFromAction:action]];
}

@end
