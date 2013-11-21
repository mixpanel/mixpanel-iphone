//
//  MPNotificationViewController.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MPNotification;
@protocol MPNotificationViewControllerDelegate;

@interface MPNotificationViewController : UIViewController

@property (nonatomic, weak) id<MPNotificationViewControllerDelegate> delegate;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) MPNotification *notification;

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationControllerWasDismissed:(MPNotificationViewController *)controller status:(BOOL)status;

@end
