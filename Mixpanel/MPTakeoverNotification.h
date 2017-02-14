//
//  MPTakeoverNotification.h
//  Mixpanel
//
//  Created by Sergio Alonso on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPNotification.h"
#import "MPNotificationButton.h"

@interface MPTakeoverNotification : MPNotification

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSUInteger titleColor;
@property (nonatomic) NSUInteger closeButtonColor;
@property (nonatomic) BOOL shouldFadeImage;
@property (nonatomic, copy) NSArray<MPNotificationButton *> *buttons;

@end
