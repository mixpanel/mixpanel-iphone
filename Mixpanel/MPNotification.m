//
//  MPNotification.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotification.h"

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID title:(NSString *)title body:(NSString *)body images:(NSArray *)images;

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
    
    NSMutableArray *images = [NSMutableArray array];
    NSArray *imageUrls = object[@"image_urls"];
    if (![imageUrls isKindOfClass:[NSArray class]]) {
        NSLog(@"inavlid notif image urls array: %@", imageUrls);
        return nil;
    }
    
    for (NSString *url in imageUrls) {
        if (![url isKindOfClass:[NSString class]] || !url) {
            NSLog(@"invalid notif image url string: %@", url);
        }
        
        NSError *error = nil;
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url] options:NSDataReadingMappedIfSafe error:&error];
        if (error || !imageData) {
            NSLog(@"image failed to load from url: %@", url);
            return nil;
        }
        
        UIImage *image = [UIImage imageWithData:imageData];
        if (image) {
            [images addObject:image];
        } else {
            NSLog(@"image failed to load from data: %@", imageData);
            return nil;
        }
    }
    
    return [[[MPNotification alloc] initWithID:[ID unsignedIntegerValue]
                                         title:title
                                          body:body
                                        images:[NSArray arrayWithArray:images]] autorelease];
}

- (id)initWithID:(NSUInteger)ID title:(NSString *)title body:(NSString *)body images:(NSArray *)images
{
    if (self = [super init]) {
        _ID = ID;
        self.title = title;
        self.body = body;
        self.images = images;
    }
    
    return self;
}

- (void)dealloc
{
    self.title = nil;
    self.body = nil;
    self.images = nil;
    [super dealloc];
}

@end
