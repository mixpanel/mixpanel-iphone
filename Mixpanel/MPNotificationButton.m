//
//  MPNotificationButton.m
//  Mixpanel
//
//  Created by Sergio Alonso on 1/25/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPNotificationButton.h"
#import "MPNotification.h"

@implementation MPNotificationButton

- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject {
    if (self = [super init]) {
        if (jsonObject == nil) {
            [MPNotification logNotificationError:@"button JSON can not be nil" withValue:@""];
            return nil;
        }
        NSString *text = jsonObject[@"text"];
        if (![text isKindOfClass:[NSString class]]) {
            [MPNotification logNotificationError:@"button text" withValue:text];
            return nil;
        }

        NSNumber *textColor = jsonObject[@"text_color"];
        if (!([textColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"button text color" withValue:textColor];
            return nil;
        }

        NSNumber *backgroundColor = jsonObject[@"bg_color"];
        if (!([backgroundColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@" button background color" withValue:backgroundColor];
            return nil;
        }

        NSNumber *borderColor = jsonObject[@"border_color"];
        if (!([borderColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"button border color" withValue:borderColor];
            return nil;
        }

        NSURL *callToActionURL = nil;
        NSObject *URLString = jsonObject[@"cta_url"];
        if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
            if (![URLString isKindOfClass:[NSString class]] || [(NSString *)URLString length] == 0) {
                [MPNotification logNotificationError:@"button cta url" withValue:URLString];
                return nil;
            }
            callToActionURL = [NSURL URLWithString:(NSString *)URLString];
            if (callToActionURL == nil) {
                [MPNotification logNotificationError:@"button cta url" withValue:URLString];
                return nil;
            }
        }

        self.jsonDescription = jsonObject;
        self.text = text;
        self.textColor = textColor.unsignedIntegerValue;
        self.backgroundColor = backgroundColor.unsignedIntegerValue;
        self.borderColor = borderColor.unsignedIntegerValue;
        self.ctaUrl = callToActionURL;
    }

    return self;
}

@end
