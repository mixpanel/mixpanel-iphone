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

@property (nonatomic, assign) id<MPNotificationViewControllerDelegate> delegate;
@property (nonatomic, retain) UIImage *backgroundImage;
@property (nonatomic, retain) MPNotification *notification;

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationControllerWasDismissed:(MPNotificationViewController *)controller status:(BOOL)status;

@end
