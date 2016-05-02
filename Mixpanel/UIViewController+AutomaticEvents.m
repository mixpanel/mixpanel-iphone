//
//  UIViewController+AutomaticEvents.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIViewController+AutomaticEvents.h"
#import "Mixpanel+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"

@implementation UIViewController (AutomaticEvents)

- (void)mp_viewDidAppear:(BOOL)animated {
    if ([self shouldTrackClass:self.class]) {
        [[Mixpanel sharedAutomatedInstance] track:kAutomaticEventName];
    }
    [self mp_viewDidAppear:animated];
}

- (BOOL)shouldTrackClass:(Class)aClass {
    static NSSet *blacklistedClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *blacklistedClassNames = @[ @"UICompatibilityInputViewController",
                                            @"UIKeyboardCandidateGridCollectionViewController",
                                            @"UIInputWindowController",
                                            @"UICompatibilityInputViewController" ];
        NSMutableSet *transformedClasses = [NSMutableSet setWithCapacity:blacklistedClassNames.count];
        for (NSString *className in blacklistedClassNames) {
            [transformedClasses addObject:NSClassFromString(className)];
        }
        blacklistedClasses = [transformedClasses copy];
    });
    
    return ![blacklistedClasses containsObject:aClass];
}

@end
