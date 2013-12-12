//
//  MPNotification.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//
//REVIEW do we need the copyright headers in every file?

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
//REVIEW are these ifdefs necessary? won't the compiler warn automatically?

#import "MPNotification.h"

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageURL:(NSURL *)imageURL;

@end

@implementation MPNotification

NSString *const MPNotificationTypeMini = @"mini";
NSString *const MPNotificationTypeTakeover = @"takeover";

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        NSLog(@"notif json object should not be nil");
        return nil;
    }

    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && [ID integerValue] > 0)) {
        NSLog(@"invalid notif id: %@", ID);
        return nil;
    }

    NSString *type = object[@"type"];
    if (![type isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif title: %@", type);
        return nil;
    }

    NSString *title = object[@"title"];
    if (![title isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif title: %@", title);
        return nil;
    }

    NSString *body = object[@"body"];
    if (![body isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif body: %@", body);
        return nil;
    }

    NSString *cta = object[@"cta"];
    if (![cta isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif cta: %@", cta);
        return nil;
    }

    NSURL *URL = nil;
    NSString *URLString = object[@"cta_url"];
    if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
        if (![URLString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif url: %@", URLString);
            return nil;
        }

        URL = [NSURL URLWithString:URLString];
        if (URL == nil) {
            NSLog(@"inavlid notif url: %@", URLString);
            return nil;
        }
    }

    NSURL *imageURL = nil;
    NSString *imageURLString = object[@"image_url"];
    if (imageURLString != nil && ![imageURLString isKindOfClass:[NSNull class]]) {
        if (![imageURLString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif image url: %@", imageURLString);
            return nil;
        }

        if ([type isEqualToString:MPNotificationTypeTakeover]) {
            NSString *imageName = [imageURLString stringByDeletingPathExtension];
            NSString *extension = [imageURLString pathExtension];
            imageURLString = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
        }

        imageURL = [NSURL URLWithString:imageURLString];
        if (imageURL == nil) {
            NSLog(@"inavlid notif image URL: %@", imageURLString);
            return nil;
        }
    }
    //REVIEW does the decide api guarantee that cta_url and image_url will be strings or null? if so, the above
    //REVIEW code could be simplified

    return [[MPNotification alloc] initWithID:[ID unsignedIntegerValue]
                                          type:type
                                         title:title
                                          body:body
                                           cta:cta
                                           url:URL
                                      imageURL:imageURL];
}

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageURL:(NSURL *)imageURL
{
    if (self = [super init]) {
        BOOL valid = YES;

        if (!(title && title.length > 0)) {
            valid = NO;
            NSLog(@"Notification title nil or empty: %@", title);
        }

        if (!(body && body.length > 0)) {
            valid = NO;
            NSLog(@"Notification body nil or empty: %@", body);
        }

        if (!([type isEqualToString:MPNotificationTypeTakeover] || [type isEqualToString:MPNotificationTypeMini])) {
            valid = NO;
            NSLog(@"Invalid notification type: %@, must be %@ or %@", type, MPNotificationTypeMini, MPNotificationTypeTakeover);
        }

        if (valid) {
            _ID = ID;
            self.type = type;
            self.title = title;
            self.body = body;
            self.imageURL = imageURL;
            self.callToAction = cta;
            self.url = url;
            self.image = nil;
        } else {
            self = nil;
        }
    }

    return self;
}


- (BOOL)loadImage
{
    if (self.image == nil && self.imageURL != nil) {
        NSError *error = nil;
        NSData *imageData = [NSData dataWithContentsOfURL:self.imageURL options:NSDataReadingMappedIfSafe error:&error];
        if (error || !imageData) {
            NSLog(@"image failed to load from url: %@", self.imageURL);
            return NO;
        }
        self.image = imageData;
    }

    return YES;
}

@end
