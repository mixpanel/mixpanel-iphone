//
//  MPInterfaceUtils.m
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPInterfaceUtils.h"

@implementation MPInterfaceUtils

+ (nullable UIViewController *)topPresentedViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

+ (BOOL)canPresentFromViewController:(UIViewController *)viewController {
    // This fixes the NSInternalInconsistencyException caused when we try present a
    // survey on a viewcontroller that is itself being presented.
    BOOL isBeingPresentedOrDismissed = [viewController isBeingPresented] ||
                                       [viewController isBeingDismissed];
    if (isBeingPresentedOrDismissed) {
        return NO;
    }
    
    Class UIAlertControllerClass = NSClassFromString(@"UIAlertController");
    BOOL isAlertController = [viewController isKindOfClass:UIAlertControllerClass];
    if (isAlertController) {
        return NO;
    }
    
    return YES;
}

@end
