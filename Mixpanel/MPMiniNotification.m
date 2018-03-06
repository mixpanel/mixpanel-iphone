//
//  MPMiniNotification.m
//  Mixpanel
//
//  Created by Sergio Alonso on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPMiniNotification.h"
#import "Mixpanel.h"

@implementation MPMiniNotification

- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject {
    if (self = [super initWithJSONObject:jsonObject]) {
        NSURL *callToActionURL = nil;
        NSObject *URLString = jsonObject[@"cta_url"];
        if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
            if (![URLString isKindOfClass:[NSString class]] || [(NSString *)URLString length] == 0) {
                [MPNotification logNotificationError:@"cta url" withValue:URLString];
                return nil;
            }
            
            callToActionURL = [NSURL URLWithString:(NSString *)URLString];
            if (callToActionURL == nil) {
                [MPNotification logNotificationError:@"cta url" withValue:URLString];
                return nil;
            }
        }
        
        NSNumber *imageTintColor = jsonObject[@"image_tint_color"];
        if (![imageTintColor isKindOfClass:[NSNumber class]]) {
            [MPNotification logNotificationError:@"image tint color" withValue:imageTintColor];
            return nil;
        }
        
        NSNumber *borderColor = jsonObject[@"border_color"];
        if (![borderColor isKindOfClass:[NSNumber class]]) {
            [MPNotification logNotificationError:@"border color" withValue:borderColor];
            return nil;
        }

        if (!self.body) {
            [MPNotification logNotificationError:@"body" withValue:self.body];
            return nil;
        }

        self.ctaUrl = callToActionURL;
        self.imageTintColor = imageTintColor.unsignedIntegerValue;
        self.borderColor = borderColor.unsignedIntegerValue;
    }
    
    return self;
}

- (NSString *)type {
    return MPNotificationTypeMini;
}

@end
