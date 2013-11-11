//
//  MPNotificationSmallViewController.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MPNotification;

@interface MPNotificationSmallViewController : UIViewController

@property (nonatomic, retain) MPNotification *notification;
@property (nonatomic, retain) UIViewController *parentController;

- (id)initWithPresentedViewController:(UIViewController *)controller notification:(MPNotification *)notification;
- (void)show;

@end
