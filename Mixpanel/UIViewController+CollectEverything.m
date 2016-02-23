//
//  UIViewController+CollectEverything.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIViewController+CollectEverything.h"
#import "Mixpanel+CollectEverything.h"
#import "MPSwizzle.h"

@implementation UIViewController (CollectEverything)

- (void)mp_viewDidAppear:(BOOL)animated {
    [[Mixpanel internalMixpanel] trackViewControllerAppeared:self];
    [self mp_viewDidAppear:animated];
}

@end
