//
//  MPNotificationSmallViewController.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MPNotification;
@protocol MPNotificationSmallViewControllerDelegate;

@interface MPNotificationSmallViewController : UIViewController

@property (nonatomic, strong) MPNotification *notification;
@property (nonatomic, strong) UIViewController *parentController;
@property (nonatomic, weak) id<MPNotificationSmallViewControllerDelegate> delegate;

- (void)show;
- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion;

@end

@protocol MPNotificationSmallViewControllerDelegate <NSObject>

- (void)notificationSmallControllerWasDismissed:(MPNotificationSmallViewController *)controller status:(BOOL)status;

@end
