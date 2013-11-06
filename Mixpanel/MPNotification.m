//
//  MPNotification.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotification.h"

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageUrls:(NSArray *)imageUrls;

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
    
    NSString *cta = object[@"cta"];
    if (![cta isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif cta: %@", cta);
        return nil;
    }
    
    NSURL *url = nil;
    NSString *url_string = object[@"cta_url"];
    if (url_string != nil && ![url_string isKindOfClass:[NSNull class]]) {
        if (![url_string isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif url: %@", url_string);
            return nil;
        }
        
        url = [NSURL URLWithString:url_string];
    }
    
    NSMutableArray *images = [NSMutableArray array];
    NSArray *imageUrls = object[@"image_urls"];
    if (![imageUrls isKindOfClass:[NSArray class]]) {
        NSLog(@"inavlid notif image urls array: %@", imageUrls);
        return nil;
    }
    
    for (NSString *imageUrl in imageUrls) {
        if (![imageUrl isKindOfClass:[NSString class]] || !imageUrl) {
            NSLog(@"invalid notif image url string: %@", imageUrl);
            return nil;
        }
        
        NSString *imageName = [imageUrl stringByDeletingPathExtension];
        NSString *extension = [imageUrl pathExtension];
        imageUrl = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
        
        NSURL *imageUrlObject = [NSURL URLWithString:imageUrl];
        if (imageUrlObject == nil) {
            NSLog(@"inavlid notif image url: %@", imageUrl);
            return nil;
        }
        
        [images addObject:imageUrlObject];
    }
    
    return [[[MPNotification alloc] initWithID:[ID unsignedIntegerValue]
                                         title:title
                                          body:body
                                           cta:cta
                                           url:url
                                        imageUrls:[NSArray arrayWithArray:images]] autorelease];
}

- (id)initWithID:(NSUInteger)ID title:(NSString *)title body:(NSString *)body cta:(NSString *)cta url:(NSURL *)url imageUrls:(NSArray *)imageUrls
{
    if (self = [super init]) {
        _ID = ID;
        self.title = title;
        self.body = body;
        self.imageUrls = imageUrls;
        self.cta = cta;
        self.url = url;
        self.images = nil;
    }
    
    return self;
}

- (void)dealloc
{
    self.title = nil;
    self.body = nil;
    self.cta = nil;
    self.url = nil;
    self.imageUrls = nil;
    self.images = nil;
    [super dealloc];
}

- (BOOL)loadImages
{
    if (self.images == nil) {
        NSMutableArray *imagesArray = [NSMutableArray arrayWithCapacity:[self.imageUrls count]];
        for (NSURL *imageUrl in self.imageUrls) {
            NSError *error = nil;
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl options:NSDataReadingMappedIfSafe error:&error];
            if (error || !imageData) {
                NSLog(@"image failed to load from url: %@", imageUrl);
                return NO;
            }
            
            [imagesArray addObject:imageData];
        }
        self.images = imagesArray;
    }
    
    return YES;
}

@end
