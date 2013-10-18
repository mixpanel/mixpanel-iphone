//
//  MPNotification.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotification.h"

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID collectionID:(NSUInteger)collectionID title:(NSString *)title body:(NSString *)body images:(NSArray *)images;

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
    
    NSArray *collections = object[@"collections"];
    if (!([collections isKindOfClass:[NSArray class]] && [collections count] > 0)) {
        NSLog(@"invalid notif collections: %@", collections);
        return nil;
    }
    
    NSDictionary *collection = collections[0];
    if (![collection isKindOfClass:[NSDictionary class]]) {
        NSLog(@"invalid notif collection: %@", collection);
        return nil;
    }
    
    NSNumber *collectionID = collection[@"id"];
    if (!([collectionID isKindOfClass:[NSNumber class]] && [collectionID integerValue] > 0)) {
        NSLog(@"invalid notif collection id: %@", collectionID);
        return nil;
    }
    
    NSString *title = collection[@"title"];
    if (![title isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif title: %@", title);
        return nil;
    }
    
    NSString *body = collection[@"body"];
    if (![body isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif body: %@", body);
        return nil;
    }
    
    NSMutableArray *images = [NSMutableArray array];
    NSArray *imageUrls = object[@"images"];
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
                            collectionID:[collectionID unsignedIntegerValue]
                                         title:title
                                          body:body
                            images:[NSArray arrayWithArray:images]] autorelease];
}

- (id)initWithID:(NSUInteger)ID collectionID:(NSUInteger)collectionID title:(NSString *)title body:(NSString *)body images:(NSArray *)images
{
    if (self = [super init]) {
        _ID = ID;
        _collectionID = collectionID;
        _title = title;
        _body = body;
        _images = images;
    }
    
    return self;
}

@end
