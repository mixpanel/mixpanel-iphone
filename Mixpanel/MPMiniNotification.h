//
//  MPMiniNotification.h
//  Mixpanel
//
//  Created by Sergio Alonso on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPNotification.h"

@interface MPMiniNotification : MPNotification

@property (nonatomic, copy) NSURL *ctaUrl;
@property (nonatomic) NSUInteger imageTintColor;
@property (nonatomic) NSUInteger borderColor;

@end
