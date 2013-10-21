//
//  MPNotificationViewController.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MPNotification;

@interface MPNotificationViewController : UIViewController

@property (nonatomic, retain) UIImage *backgroundImage;
@property (nonatomic, retain) MPNotification *notification;

@end
