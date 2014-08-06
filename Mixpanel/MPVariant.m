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
#import "MPValueTransformers.h"

#import "MPTweakStore.h"
#import "MPTweak.h"

@interface MPVariantAction : NSObject <NSCoding>

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

#pragma mark -

@interface MPVariantTweak : NSObject <NSCoding>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *encoding;
@property (nonatomic, strong) MPTweakValue value;

+ (MPVariantTweak *)tweakWithJSONObject:(NSDictionary *)object;
- (id)initWithName:(NSString *)name
          encoding:(NSString *)encoding
             value:(MPTweakValue)value;
- (void)execute;
- (void)stop;

@end

#pragma mark -

@implementation MPVariant

#pragma mark Constructing Variants

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

    NSArray *tweaks = [object objectForKey:@"tweaks"];
    if (![tweaks isKindOfClass:[NSArray class]]) {
        NSLog(@"variant requires an array of tweaks");
        return nil;
    }

    return [[MPVariant alloc] initWithID:[ID unsignedIntegerValue]
                            experimentID:[experimentID unsignedIntegerValue]
                                 actions:actions
                                  tweaks:tweaks];
}

- (id)init
{
    return [self initWithID:0 experimentID:0 actions:nil tweaks:nil];
}

- (id)initWithID:(NSUInteger)ID experimentID:(NSUInteger)experimentID actions:(NSArray *)actions tweaks:(NSArray *)tweaks
{
    if(self = [super init]) {
        self.ID = ID;
        self.experimentID = experimentID;
        self.actions = [NSMutableArray array];
        self.tweaks = [NSMutableArray array];
        [self addTweaksFromJSONObject:tweaks andExecute:NO];
        [self addActionsFromJSONObject:actions andExecute:NO];
        _finished = NO;
        _running = NO;
    }
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.ID = [(NSNumber *)[aDecoder decodeObjectForKey:@"ID"] unsignedLongValue];
        self.experimentID = [(NSNumber *)[aDecoder decodeObjectForKey:@"experimentID"] unsignedLongValue];
        self.actions = [aDecoder decodeObjectForKey:@"actions"];
        self.tweaks = [aDecoder decodeObjectForKey:@"tweaks"];
        _finished = [(NSNumber *)[aDecoder decodeObjectForKey:@"finished"] boolValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithUnsignedLong:_ID] forKey:@"ID"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedLong:_experimentID] forKey:@"experimentID"];
    [aCoder encodeObject:_actions forKey:@"actions"];
    [aCoder encodeObject:_tweaks forKey:@"tweaks"];
    [aCoder encodeObject:[NSNumber numberWithBool:_finished] forKey:@"finished"];
}

#pragma mark Actions

- (void)addActionsFromJSONObject:(NSArray *)actions andExecute:(BOOL)exec
{
    for (NSDictionary *object in actions) {
        [self addActionFromJSONObject:object andExecute:exec];
    }
}

- (void)addActionFromJSONObject:(NSDictionary *)object andExecute:(BOOL)exec
{
    MPVariantAction *action = [MPVariantAction actionWithJSONObject:object];
    if(action) {
        [self.actions addObject:action];
        if (exec) {
            [action execute];
        }
    }
}

- (void)removeActionWithName:(NSString *)name
{
    for (MPVariantAction *action in self.actions) {
        if([action.name isEqualToString:name]) {
            [action stop];
            [self.actions removeObjectIdenticalTo:action];
            break;
        }
    }
}

#pragma mark Tweaks

- (void)addTweaksFromJSONObject:(NSArray *)tweaks andExecute:(BOOL)exec
{
    for (NSDictionary *object in tweaks) {
        [self addTweakFromJSONObject:object andExecute:exec];
    }
}

- (void)addTweakFromJSONObject:(NSDictionary *)object andExecute:(BOOL)exec
{
    MPVariantTweak *tweak = [MPVariantTweak tweakWithJSONObject:object];
    if(tweak) {
        [self.tweaks addObject:tweak];
        if (exec) {
            [tweak execute];
        }
    }
}

#pragma mark Execution

- (void)execute {
    if (!self.running) {
        for (MPVariantTweak *tweak in self.tweaks) {
            [tweak execute];
        }
        for (MPVariantAction *action in self.actions) {
            [action execute];
        }
        _running = YES;
    }
}

- (void)stop {
    for (MPVariantAction *action in self.actions) {
        [action stop];
    }
    for (MPVariantTweak *tweak in self.tweaks) {
        [tweak stop];
    }
}

- (void)finish {
    for (MPVariantTweak *tweak in self.tweaks) {
        [tweak stop];
    }
    _finished = YES;
}

#pragma mark Equality

- (BOOL)isEqualToVariant:(MPVariant *)variant
{
    return self.ID == variant.ID;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[MPVariant class]]) {
        return NO;
    }

    return [self isEqualToVariant:(MPVariant *)object];
}

- (NSUInteger)hash
{
    return self.ID;
}

@end

#pragma mark -

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

    // Optional parameters
    NSArray *original = object[@"original"];
    NSString *name = object[@"name"];
    BOOL swizzle = !object[@"swizzle"] || [object[@"swizzle"] boolValue];
    Class swizzleClass = NSClassFromString(object[@"swizzleClass"]);
    SEL swizzleSelector = NSSelectorFromString(object[@"swizzleSelector"]);

    return [[MPVariantAction alloc] initWithName:name
                                            path:path
                                        selector:selector
                                            args:args
                                        original:original
                                         swizzle:swizzle
                                    swizzleClass:swizzleClass
                                 swizzleSelector:swizzleSelector];
}

- (id)init
{
    [NSException raise:@"NotSupported" format:@"Please call initWithName: path: selector: args: original: swizzle: swizzleClass: swizzleSelector:"];
    return nil;
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
    if ((self = [super init])) {
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
            swizzleSelector = @selector(didMoveToWindow);
#pragma clang diagnostic pop
        }
        self.swizzleSelector = swizzleSelector;

        self.appliedTo = [NSHashTable hashTableWithOptions:(NSHashTableWeakMemory|NSHashTableObjectPointerPersonality)];
    }
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.name = [aDecoder decodeObjectForKey:@"name"];

        self.path = [MPObjectSelector objectSelectorWithString:[aDecoder decodeObjectForKey:@"path"]];
        self.selector = NSSelectorFromString([aDecoder decodeObjectForKey:@"selector"]);
        self.args = [aDecoder decodeObjectForKey:@"args"];
        self.original = [aDecoder decodeObjectForKey:@"original"];

        self.swizzle = [(NSNumber *)[aDecoder decodeObjectForKey:@"swizzle"] boolValue];
        self.swizzleClass = NSClassFromString([aDecoder decodeObjectForKey:@"swizzleClass"]);
        self.swizzleSelector = NSSelectorFromString([aDecoder decodeObjectForKey:@"swizzleSelector"]);
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_name forKey:@"name"];

    [aCoder encodeObject:_path.string forKey:@"path"];
    [aCoder encodeObject:NSStringFromSelector(_selector) forKey:@"selector"];
    [aCoder encodeObject:_args forKey:@"args"];
    [aCoder encodeObject:_original forKey:@"original"];

    [aCoder encodeObject:[NSNumber numberWithBool:_swizzle] forKey:@"swizzle"];
    [aCoder encodeObject:NSStringFromClass(_swizzleClass) forKey:@"swizzleClass"];
    [aCoder encodeObject:NSStringFromSelector(_swizzleSelector) forKey:@"swizzleSelector"];
}

#pragma mark Executing Actions

- (void)execute
{
    NSLog(@"Executing %@", self);
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
    NSLog(@"Stopping %@ (%lu to be reverted)", self, (unsigned long)[self.appliedTo count]);
    // Stop this change from applying in future
    [MPSwizzler unswizzleSelector:self.swizzleSelector
                          onClass:self.swizzleClass
                            named:self.name];

    // Undo the current changes (if we know how to undo them)
    if (self.original) {
        [[self class] executeSelector:self.selector withArgs:self.original onObjects:[self.appliedTo allObjects]];
        [self.appliedTo removeAllObjects];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Action: Change %@ on %@ matching %@ from %@ to %@", NSStringFromSelector(self.selector), NSStringFromClass(self.class), self.path.string, self.original, self.args];
}

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
                        id arg = transformValue(argTuple[0], argTuple[1]);

                        // Unpack NSValues to their base types.
                        if ([arg isKindOfClass:[NSValue class]]) {
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
                        NSLog(@"Invoking on %p", o);
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

#pragma mark -

@implementation MPVariantTweak

+ (MPVariantTweak *)tweakWithJSONObject:(NSDictionary *)object
{
    // Required parameters
    NSString *name = object[@"name"];
    if (![name isKindOfClass:[NSString class]]) {
        NSLog(@"invalid name: %@", name);
        return nil;
    }

    NSString *encoding = object[@"encoding"];
    if (![encoding isKindOfClass:[NSString class]]) {
        NSLog(@"invalid encoding: %@", encoding);
        return nil;
    }

    MPTweakValue value = object[@"value"];
    if (value == nil) {
        NSLog(@"invalid value: %@", value);
        return nil;
    }

    return [[MPVariantTweak alloc] initWithName:name
                                       encoding:encoding
                                          value:value];
}

- (id)init
{
    [NSException raise:@"NotSupported" format:@"Please call initWithName:name encoding:encoding value:value"];
    return nil;

}

- (id)initWithName:(NSString *)name
          encoding:(NSString *)encoding
             value:(MPTweakValue)value
{
    if ((self = [super init])) {
        self.name = name;
        self.encoding = encoding;
        self.value = value;
    }
    return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.encoding = [aDecoder decodeObjectForKey:@"encoding"];
        self.value = [aDecoder decodeObjectForKey:@"value"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.encoding forKey:@"encoding"];
    [aCoder encodeObject:self.value forKey:@"value"];
}

#pragma mark Executing Actions

- (void)execute
{
    MPTweak *mpTweak = [[MPTweakStore sharedInstance] tweakWithName:self.name];;
    if (mpTweak) {
        //TODO, this may change, but for now sending an NSNull will revert the MPTweak back to its default.
        if ([self.value isKindOfClass:[NSNull class]]) {
            mpTweak.currentValue = mpTweak.defaultValue;
        } else {
            mpTweak.currentValue = self.value;
        }
    }
}

- (void)stop
{
    MPTweak *mpTweak = [[MPTweakStore sharedInstance] tweakWithName:self.name];
    if (mpTweak) {
        mpTweak.currentValue = mpTweak.defaultValue;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Tweak: %@ = %@", self.name, self.value];
}

@end
