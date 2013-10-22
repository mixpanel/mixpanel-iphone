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
@property(nonatomic,readonly) NSArray *images;
@property(nonatomic,readonly) NSString *title;
@property(nonatomic,readonly) NSString *body;

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object;

@end
