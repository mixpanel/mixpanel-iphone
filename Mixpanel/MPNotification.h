//
//  MPNotification.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNotification : NSObject

extern NSString *const MPNotificationTypeMini;
extern NSString *const MPNotificationTypeTakeover;

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, strong) NSData *image;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSString *callToAction;
@property (nonatomic, strong) NSURL *callToActionURL;

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object;

- (BOOL)loadImage; //REVIEW MPNotification should have an -(UIImage)image method that lazy-loads the image and
                   //REVIEW returns nil if it can't. loading can be private

@end
