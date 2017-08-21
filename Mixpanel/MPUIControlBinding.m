//
//  MPUIControlBinding.m
//  HelloMixpanel
//
//  Created by Amanda Canyon on 8/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MixpanelPrivate.h"
#import "MPSwizzler.h"
#import "MPUIControlBinding.h"
#import "NSThread+MPHelpers.h"

@interface MPUIControlBinding()

/*
 This table contains all the UIControls we are currently bound to
 */
@property (nonatomic, copy) NSHashTable *appliedTo;
/*
 A table of all objects that matched the full path including
 predicates the last time they dispatched a UIControlEventTouchDown
 */
@property (nonatomic, copy) NSHashTable *verified;

- (void)stopOnView:(UIView *)view;

@end

@implementation MPUIControlBinding

+ (NSString *)typeName
{
    return @"ui_control";
}

+ (MPEventBinding *)bindingWithJSONObject:(NSDictionary *)object
{
    NSString *path = object[@"path"];
    if (![path isKindOfClass:[NSString class]] || path.length < 1) {
        NSLog(@"must supply a view path to bind by");
        return nil;
    }

    NSString *eventName = object[@"event_name"];
    if (![eventName isKindOfClass:[NSString class]] || eventName.length < 1 ) {
        NSLog(@"binding requires an event name");
        return nil;
    }

    if (!([object[@"control_event"] unsignedIntegerValue] & UIControlEventAllEvents)) {
        NSLog(@"must supply a valid UIControlEvents value for control_event");
        return nil;
    }

    UIControlEvents verifyEvent = [object[@"verify_event"] unsignedIntegerValue];
    return [[MPUIControlBinding alloc] initWithEventName:eventName
                                        onPath:path
                              withControlEvent:[object[@"control_event"] unsignedIntegerValue]
                                          andVerifyEvent:verifyEvent];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (MPEventBinding *)bindngWithJSONObject:(NSDictionary *)object
{
    return [self bindingWithJSONObject:object];
}
#pragma clang diagnostic pop

- (instancetype)initWithEventName:(NSString *)eventName
                 onPath:(NSString *)path
       withControlEvent:(UIControlEvents)controlEvent
         andVerifyEvent:(UIControlEvents)verifyEvent
{
    if (self = [super initWithEventName:eventName onPath:path]) {
        [self setSwizzleClass:[UIControl class]];
        _controlEvent = controlEvent;

        if (verifyEvent == 0) {
            if (controlEvent & UIControlEventAllTouchEvents) {
                verifyEvent = UIControlEventTouchDown;
            } else if (controlEvent & UIControlEventAllEditingEvents) {
                verifyEvent = UIControlEventEditingDidBegin;
            }
        }
        _verifyEvent = verifyEvent;

        [self resetAppliedTo];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Event Binding: '%@' for '%@'", [self eventName], [self path]];
}

- (void)resetAppliedTo
{
    self.verified = [NSHashTable hashTableWithOptions:(NSHashTableWeakMemory|NSHashTableObjectPointerPersonality)];
    self.appliedTo = [NSHashTable hashTableWithOptions:(NSHashTableWeakMemory|NSHashTableObjectPointerPersonality)];
}

#pragma mark -- Executing Actions

- (void)execute
{
    if (!self.appliedTo) {
        [self resetAppliedTo];
    }
    
    if (!self.running) {
        void (^executeBlock)(id, SEL) = ^(id view, SEL command) {
            [NSThread mp_safelyRunOnMainThreadSync:^{
                NSArray *objects;
                NSObject *root = [[Mixpanel sharedUIApplication] keyWindow].rootViewController;
                if (view && [self.appliedTo containsObject:view]) {
                    if (![self.path fuzzyIsLeafSelected:view fromRoot:root]) {
                        [self stopOnView:view];
                        [self.appliedTo removeObject:view];
                    }
                } else {
                    // select targets based off path
                    if (view) {
                        if ([self.path fuzzyIsLeafSelected:view fromRoot:root]) {
                            objects = @[view];
                        } else {
                            objects = @[];
                        }
                    } else {
                        objects = [self.path fuzzySelectFromRoot:root];
                    }

                    for (UIControl *control in objects) {
                        if ([control isKindOfClass:[UIControl class]]) {
                            if (self.verifyEvent != 0 && self.verifyEvent != self.controlEvent) {
                                [control addTarget:self
                                            action:@selector(preVerify:forEvent:)
                                  forControlEvents:self.verifyEvent];
                            }

                            [control addTarget:self
                                        action:@selector(execute:forEvent:)
                              forControlEvents:self.controlEvent];
                            [self.appliedTo addObject:control];
                        }
                    }
                }
            }];
        };

        executeBlock(nil, _cmd);

        [MPSwizzler swizzleSelector:NSSelectorFromString(@"didMoveToWindow")
                            onClass:self.swizzleClass
                          withBlock:executeBlock
                              named:self.name];
        [MPSwizzler swizzleSelector:NSSelectorFromString(@"didMoveToSuperview")
                            onClass:self.swizzleClass
                          withBlock:executeBlock
                              named:self.name];
        self.running = true;
    }
}

- (void)stop
{
    if (self.running) {
        // remove what has been swizzled
        [MPSwizzler unswizzleSelector:NSSelectorFromString(@"didMoveToWindow")
                            onClass:self.swizzleClass
                              named:self.name];
        [MPSwizzler unswizzleSelector:NSSelectorFromString(@"didMoveToSuperview")
                            onClass:self.swizzleClass
                              named:self.name];

        // remove target-action pairs
        for (UIControl *control in self.appliedTo.allObjects) {
            if (control && [control isKindOfClass:[UIControl class]]) {
                [self stopOnView:control];
            }
        }
        [self resetAppliedTo];
        self.running = false;
    }
}

- (void)stopOnView:(UIControl *)view
{
    if (self.verifyEvent != 0 && self.verifyEvent != self.controlEvent) {
        [view removeTarget:self
                    action:@selector(preVerify:forEvent:)
          forControlEvents:self.verifyEvent];
    }
    [view removeTarget:self
                action:@selector(execute:forEvent:)
      forControlEvents:self.controlEvent];
}

#pragma mark -- To execute for Target-Action event firing

- (BOOL)verifyControlMatchesPath:(id)control
{
    NSObject *root = [[Mixpanel sharedUIApplication] keyWindow].rootViewController;
    return [self.path isLeafSelected:control fromRoot:root];
}

- (void)preVerify:(id)sender forEvent:(UIEvent *)event
{
    if ([self verifyControlMatchesPath:sender]) {
        [self.verified addObject:sender];
    } else {
        [self.verified removeObject:sender];
    }
}

- (void)execute:(id)sender forEvent:(UIEvent *)event
{
    BOOL shouldTrack;
    if (self.verifyEvent != 0 && self.verifyEvent != self.controlEvent) {
        shouldTrack = [self.verified containsObject:sender];
    } else {
        shouldTrack = [self verifyControlMatchesPath:sender];
    }
    if (shouldTrack) {
        [[self class] track:[self eventName] properties:nil];
    }
}

#pragma mark -- NSCoder

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:@(_controlEvent) forKey:@"controlEvent"];
    [aCoder encodeObject:@(_verifyEvent) forKey:@"verifyEvent"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        _controlEvent = [[aDecoder decodeObjectForKey:@"controlEvent"] unsignedIntegerValue];
        _verifyEvent = [[aDecoder decodeObjectForKey:@"verifyEvent"] unsignedIntegerValue];
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:[MPUIControlBinding class]]) {
        return NO;
    } else {
        return [super isEqual:other] && self.controlEvent == ((MPUIControlBinding *)other).controlEvent && self.verifyEvent == ((MPUIControlBinding *)other).verifyEvent;
    }
}

- (NSUInteger)hash {
    return [super hash] ^ self.controlEvent ^ self.verifyEvent;
}

@end
