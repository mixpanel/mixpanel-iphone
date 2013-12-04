//
//  MPNotification.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNotification : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSURL *imageUrl;
@property (nonatomic, strong) NSData *image;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSString *cta;
@property (nonatomic, strong) NSURL *url;

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object;

- (BOOL)loadImage;

@end
