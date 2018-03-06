//
//  MPTakeoverNotification.m
//  Mixpanel
//
//  Created by Sergio Alonso on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPTakeoverNotification.h"
#import "Mixpanel.h"

@implementation MPTakeoverNotification

- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject {
    if (self = [super initWithJSONObject:jsonObject]) {
        NSString *title = jsonObject[@"title"];
        if ([title isEqual:[NSNull null]]) {
            title = nil;
        }

        NSNumber *titleColor = jsonObject[@"title_color"];
        if (!([titleColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"title color" withValue:titleColor];
            return nil;
        }
        
        NSNumber *closeButton = jsonObject[@"close_color"];
        if (!([closeButton isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"close color" withValue:closeButton];
            return nil;
        }
        
        NSArray *buttonsJson = jsonObject[@"buttons"];
        NSMutableArray *buttons = [NSMutableArray array];
        for (NSDictionary *buttonJson in buttonsJson) {
            MPNotificationButton *notificationButton = [[MPNotificationButton alloc] initWithJSONObject:buttonJson];
            if (notificationButton) {
                [buttons addObject:notificationButton];
            } else {
                return nil;
            }
        }
        
        if (buttons.count == 0) {
            [MPNotification logNotificationError:@"buttons" withValue:@"not enough (0)"];
            return nil;
        }

        NSNumber *shouldFadeIamge = self.extrasDescription[@"image_fade"];
        if (!([shouldFadeIamge isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"image fade" withValue:shouldFadeIamge];
            return nil;
        }

        self.title = title;
        self.titleColor = titleColor.unsignedIntegerValue;
        self.closeButtonColor = closeButton.unsignedIntegerValue;
        self.buttons = [buttons copy];
        self.shouldFadeImage = [shouldFadeIamge boolValue];
    }
    
    return self;
}

- (NSString *)type {
    return MPNotificationTypeTakeover;
}

@end
