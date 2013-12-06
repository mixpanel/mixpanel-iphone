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

//REVIEW use constants for types
//REVIEW eg,
//REVIEW static NSString *MPNotificationTypeMini = @"mini";
//REVIEW static NSString *MPNotificationTypeTakeover = @"takeover";

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageUrl:(NSURL *)imageUrl;

@end

@implementation MPNotification

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

    NSURL *url = nil;
    NSString *urlString = object[@"cta_url"];
    //REVIEW url -> URL
    if (urlString != nil && ![urlString isKindOfClass:[NSNull class]]) {
        if (![urlString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif url: %@", urlString);
            return nil;
        }

        url = [NSURL URLWithString:urlString];
        if (url == nil) {
            NSLog(@"inavlid notif url: %@", urlString);
            return nil;
        }
    }

    NSURL *imageUrl = nil;
    NSString *imageUrlString = object[@"image_url"];
    if (imageUrlString != nil && ![imageUrlString isKindOfClass:[NSNull class]]) {
        if (![imageUrlString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif image url: %@", imageUrlString);
            return nil;
        }

        if ([type isEqualToString:@"takeover"]) {
            NSString *imageName = [imageUrlString stringByDeletingPathExtension];
            NSString *extension = [imageUrlString pathExtension];
            imageUrlString = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
        }

        imageUrl = [NSURL URLWithString:imageUrlString];
        if (imageUrl == nil) {
            NSLog(@"inavlid notif image url: %@", imageUrlString);
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
                                           url:url
                                      imageUrl:imageUrl];
}

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageUrl:(NSURL *)imageUrl
{
    //REVIEW enforce everything that can be here, for example:
    //REVIEW     type == mini or type == takeover
    //REVIEW     title len > 0
    //REVIEW     body len > 0
    if (self = [super init]) {
        _ID = ID;
        self.type = type;
        self.title = title;
        self.body = body;
        self.imageUrl = imageUrl;
        self.cta = cta;
        self.url = url;
        self.image = nil;
    }

    return self;
}


- (BOOL)loadImage
{
    if (self.image == nil && self.imageUrl != nil) {
        NSError *error = nil;
        NSData *imageData = [NSData dataWithContentsOfURL:self.imageUrl options:NSDataReadingMappedIfSafe error:&error];
        if (error || !imageData) {
            NSLog(@"image failed to load from url: %@", self.imageUrl);
            return NO;
        }
        self.image = imageData;
    }

    return YES;
}

@end
