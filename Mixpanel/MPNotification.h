//
//  MPNotification.h
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNotification : NSObject

@property(nonatomic,readonly) NSUInteger ID;
@property(nonatomic,retain) NSArray *images;
@property(nonatomic,retain) NSString *title;
@property(nonatomic,retain) NSString *body;
@property(nonatomic,retain) NSString *cta;
@property(nonatomic,retain) NSURL *url;

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object;

@end
