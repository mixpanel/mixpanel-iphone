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

@interface MPVariantAction ()

@property (nonatomic, strong)NSString *name;

@property (nonatomic, strong)MPObjectSelector *path;
@property (nonatomic, assign)SEL selector;
@property (nonatomic, strong)NSArray *args;
@property (nonatomic, strong)NSArray *original;

@property (nonatomic, assign)BOOL swizzle;
@property (nonatomic, assign)Class swizzleClass;
@property (nonatomic, assign)SEL swizzleSelector;

@property (nonatomic, copy) NSHashTable *appliedTo;

+ (MPVariantAction *)actionWithJSONObject:(NSDictionary *)object;
- (id) initWithName:(NSString *)name
               path:(MPObjectSelector *)path
           selector:(SEL)selector
               args:(NSArray *)args
           original:(NSArray *)original
            swizzle:(BOOL)swizzle
       swizzleClass:(Class)swizzleClass
    swizzleSelector:(SEL)swizzleSelector;

- (void)execute;
- (void)stop;

@end

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
        [self addActionsFromJSONObject:actions andExecute:NO];
    }
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.ID = [(NSNumber *)[aDecoder decodeObjectForKey:@"ID"] unsignedLongValue];
        self.experimentID = [(NSNumber *)[aDecoder decodeObjectForKey:@"experimentID"] unsignedLongValue];
        self.actions = [aDecoder decodeObjectForKey:@"actions"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithUnsignedLong:_ID] forKey:@"ID"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedLong:_experimentID] forKey:@"experimentID"];
    [aCoder encodeObject:_actions forKey:@"actions"];
}

#pragma mark - Actions

- (void) addActionsFromJSONObject:(NSArray *)actions andExecute:(BOOL)exec
{
    for (NSDictionary *action in actions) {
        [self addActionFromJSONObject:action andExecute:exec];
    }
}

- (void) addActionFromJSONObject:(NSDictionary *)action andExecute:(BOOL)exec
{
    MPVariantAction *mpAction = [MPVariantAction actionWithJSONObject:action];
    if(action) {
        [self.actions addObject:mpAction];
        if (exec) {
            [mpAction execute];
        }
    }
}

- (void)removeActionWithName:(NSString *)name
{
    for (MPVariantAction *a in self.actions) {
        if([a.name isEqualToString:name]) {
            [self.actions removeObjectIdenticalTo:a];
            break;
        }
    }
}

- (void)execute {
    for (MPVariantAction *action in self.actions) {
        [action execute];
    }
}

- (void)stop {
    for (MPVariantAction *action in self.actions) {
        [action stop];
    }
}

@end

@implementation MPVariantAction

+ (MPVariantAction *)actionWithJSONObject:(NSDictionary *)object
{
    // Required parameters
    MPObjectSelector *path = [MPObjectSelector objectSelectorWithString:object[@"path"]];
    if (!path) {
        NSLog(@"invalid action path: %@", object[@"path"]);
        return nil;
    }

    SEL selector = NSSelectorFromString(object[@"selector"]);
    if (selector == (SEL)0) {
        NSLog(@"invalid action selector: %@", object[@"selector"]);
        return nil;
    }

    NSArray *args = object[@"args"];
    if (![args isKindOfClass:[NSArray class]]) {
        NSLog(@"invalid action arguments: %@", args);
        return nil;
    }

    NSArray *original = object[@"original"];
    if (![original isKindOfClass:[NSArray class]]) {
        NSLog(@"invalid action original arguments: %@", original);
        return nil;
    }

    // Optional parameters
    NSString *name = object[@"name"];
    BOOL swizzle = !object[@"swizzle"] || [object[@"swizzle"] boolValue];
    Class swizzleClass = NSClassFromString(object[@"swizzleClass"]);
    SEL swizzleSelector = NSSelectorFromString(object[@"swizzleSelector"]);

    return [[MPVariantAction alloc] initWithName:name path:path selector:selector args:args original:original swizzle:swizzle swizzleClass:swizzleClass swizzleSelector:swizzleSelector];
}

- (id) initWithName:(NSString *)name
               path:(MPObjectSelector *)path
           selector:(SEL)selector
               args:(NSArray *)args
           original:(NSArray *)original
            swizzle:(BOOL)swizzle
       swizzleClass:(Class)swizzleClass
    swizzleSelector:(SEL)swizzleSelector
{
    if ((self = [self init])) {
        self.path = path;
        self.selector = selector;
        self.args = args;
        self.original = original;
        self.swizzle = swizzle;

        if (!name) {
            name = [[NSUUID UUID] UUIDString];
        }
        self.name = name;

        if (!swizzleClass) {
            swizzleClass = [path selectedClass];
        }
        if (!swizzleClass) {
            swizzleClass = [UIView class];
        }
        self.swizzleClass = swizzleClass;

        if (!swizzleSelector) {
            swizzleSelector = @selector(didMoveToWindow);
        }
        self.swizzleSelector = swizzleSelector;

        self.appliedTo = [NSHashTable hashTableWithOptions:(NSHashTableWeakMemory|NSHashTableObjectPointerPersonality)];
    }
    return self;
}

- (void)execute
{
    // Block to execute on swizzle
    void (^executeBlock)(id, SEL) = ^(id view, SEL command){
        NSArray *objects = [[self class] executeSelector:self.selector
                                                  withArgs:self.args
                                                    onPath:self.path
                                                  fromRoot:[[UIApplication sharedApplication] keyWindow].rootViewController
                                                    toLeaf:view];

        for (id o in objects) {
            [self.appliedTo addObject:o];
        }
    };

    // Execute once in case the view to be changed is already on screen.
    executeBlock(nil, _cmd);

    // The block that is called on swizzle executes the executeBlock on the main queue to minimize time
    // spent in the swizzle, and allow the newly added UI elements time to be initialized on screen.
    void (^swizzleBlock)(id, SEL) = ^(id view, SEL command){
        dispatch_async(dispatch_get_main_queue(), ^{ executeBlock(view, command);});
    };

    if (self.swizzle) {
        // Swizzle the method needed to check for this object coming onscreen
        [MPSwizzler swizzleSelector:self.swizzleSelector
                            onClass:self.swizzleClass
                          withBlock:swizzleBlock
                              named:self.name];
    }
}

- (void)stop
{
    // Stop this change from applying in future
    [MPSwizzler unswizzleSelector:self.swizzleSelector
                          onClass:self.swizzleClass
                            named:self.name];

    // Undo the present changes
    [[self class] executeSelector:self.selector withArgs:self.original onObjects:[self.appliedTo allObjects]];
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

/*+ (BOOL)setValue:(id)value forKey:(NSString *)key onPath:(MPObjectSelector *)path fromRoot:(UIView *)root toLeaf:(NSObject *)leaf
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
}*/

+ (NSArray *)executeSelector:(SEL)selector withArgs:(NSArray *)args onPath:(MPObjectSelector *)path fromRoot:(NSObject *)root toLeaf:(NSObject *)leaf
{
    NSLog(@"Looking for objects matching %@ on path from %@ to %@", path, [root class], [leaf class]);
    if (leaf){
        if ([path isLeafSelected:leaf fromRoot:root]) {
            return [self executeSelector:selector withArgs:args onObjects:@[leaf]];
        } else {
            return @[];
        }
    } else {
        return [self executeSelector:selector withArgs:args onObjects:[path selectFromRoot:root]];
    }
}

+ (NSArray *)executeSelector:(SEL)selector withArgs:(NSArray *)args onObjects:(NSArray *)objects
{
    NSMutableArray *executedOn = [NSMutableArray array];
    if (objects && [objects count] > 0) {
        NSLog(@"Invoking on %lu objects", (unsigned long)[objects count]);
        for (NSObject *o in objects) {
            NSMethodSignature *signature = [o methodSignatureForSelector:selector];
            if (signature != nil) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation retainArguments];
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
                    [executedOn addObject:o];
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
    return [executedOn copy];
}

@end


