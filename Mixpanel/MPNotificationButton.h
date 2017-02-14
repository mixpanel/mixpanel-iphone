//
//  MPNotificationButton.h
//  Mixpanel
//
//  Created by Sergio Alonso on 1/25/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNotificationButton : NSObject

@property (nonatomic, copy) NSDictionary *jsonDescription;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSUInteger textColor;
@property (nonatomic) NSUInteger backgroundColor;
@property (nonatomic) NSUInteger borderColor;
@property (nonatomic, copy) NSURL *ctaUrl;

- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

@end
