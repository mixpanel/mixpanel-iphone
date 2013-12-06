//
//  MPNotificationViewController.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

//REVIEW with surveys, there's a single MPSurveyQuestionViewController.m file that contains a base class for
//REVIEW question view controllers and the subclasses, which share the delegate. i think the same would be good
//REVIEW here, i.e., a single MPNotificationViewController.m file containing:
//REVIEW
//REVIEW     MPNotificationViewController (base class)
//REVIEW     MPMiniNotificationViewController
//REVIEW     MPTakeoverNotificationViewController
//REVIEW     MPNotificationViewControllerDelegate (shared delegate)

#import <UIKit/UIKit.h>

@class MPNotification; //REVIEW why not #import "MPNotification.h"
@protocol MPNotificationViewControllerDelegate; //REVIEW MPTakeoverNotificationViewControllerDelegate

@interface MPNotificationViewController : UIViewController //REVIEW MPTakeoverNotificationViewController

@property (nonatomic, weak) id<MPNotificationViewControllerDelegate> delegate;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) MPNotification *notification;

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationControllerWasDismissed:(MPNotificationViewController *)controller status:(BOOL)status;
//REVIEW (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithStatus:(BOOL)status;

@end
