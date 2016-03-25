//
//  UIViewController+AutomaticEvents.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIViewController+AutomaticEvents.h"
#import "Mixpanel+AutomaticEvents.h"
#import "MPSwizzle.h"

@implementation UIViewController (AutomaticEvents)

- (void)mp_viewDidAppear:(BOOL)animated {
    [[Mixpanel sharedAutomatedInstance] trackViewControllerAppeared:self];
    [self mp_viewDidAppear:animated];
}

@end
