#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "MPNotification.h"

@interface MPNotification ()

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body callToAction:(NSString *)callToAction callToActionURL:(NSURL *)callToActionURL imageURL:(NSURL *)imageURL;

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

    NSString *callToAction = object[@"cta"];
    if (![callToAction isKindOfClass:[NSString class]]) {
        NSLog(@"invalid notif cta: %@", callToAction);
        return nil;
    }

    NSURL *callToActionURL = nil;
    NSString *URLString = object[@"cta_url"];
    if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
        if (![URLString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif URL: %@", URLString);
            return nil;
        }

        callToActionURL = [NSURL URLWithString:URLString];
        if (callToActionURL == nil) {
            NSLog(@"inavlid notif URL: %@", URLString);
            return nil;
        }
    }

    NSURL *imageURL = nil;
    NSString *imageURLString = object[@"image_url"];
    if (imageURLString != nil && ![imageURLString isKindOfClass:[NSNull class]]) {
        if (![imageURLString isKindOfClass:[NSString class]]) {
            NSLog(@"invalid notif image URL: %@", imageURLString);
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
                                           callToAction:callToAction
                                           callToActionURL:callToActionURL
                                      imageURL:imageURL];
}

- (id)initWithID:(NSUInteger)ID type:(NSString *)type title:(NSString *)title body:(NSString *)body callToAction:(NSString *)callToAction callToActionURL:(NSURL *)callToActionURL imageURL:(NSURL *)imageURL
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
            self.callToAction = callToAction;
            self.callToActionURL = callToActionURL;
            self.image = nil;
        } else {
            self = nil;
        }
    }

    return self;
}

- (NSData *)image
{
    if (_image == nil && _imageURL != nil) {
        NSError *error = nil;
        NSData *imageData = [NSData dataWithContentsOfURL:_imageURL options:NSDataReadingMappedIfSafe error:&error];
        if (error || !imageData) {
            NSLog(@"image failed to load from URL: %@", _imageURL);
            return NO;
        }
        _image = imageData;
    }
    return _image;
}

@end
