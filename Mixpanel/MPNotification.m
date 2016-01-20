#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "MPLogger.h"
#import "MPNotification.h"

@interface MPNotification ()

- (instancetype)initWithID:(NSUInteger)ID messageID:(NSUInteger)messageID type:(NSString *)type title:(NSString *)title body:(NSString *)body callToAction:(NSString *)callToAction callToActionURL:(NSURL *)callToActionURL imageURL:(NSURL *)imageURL;

@end

@implementation MPNotification

NSString *const MPNotificationTypeMini = @"mini";
NSString *const MPNotificationTypeTakeover = @"takeover";

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        MixpanelError(@"notification json object should not be nil");
        return nil;
    }

    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && [ID integerValue] > 0)) {
        MixpanelError(@"invalid notification id: %@", ID);
        return nil;
    }

    NSNumber *messageID = object[@"message_id"];
    if (!([messageID isKindOfClass:[NSNumber class]] && [messageID integerValue] > 0)) {
        MixpanelError(@"invalid notification message id: %@", messageID);
        return nil;
    }

    NSString *type = object[@"type"];
    if (![type isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notification type: %@", type);
        return nil;
    }

    NSString *title = object[@"title"];
    if (![title isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notification title: %@", title);
        return nil;
    }

    NSString *body = object[@"body"];
    if (![body isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notification body: %@", body);
        return nil;
    }

    NSString *callToAction = object[@"cta"];
    if (![callToAction isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notification call to action: %@", callToAction);
        return nil;
    }

    NSURL *callToActionURL = nil;
    NSObject *URLString = object[@"cta_url"];
    if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
        if (![URLString isKindOfClass:[NSString class]] || [(NSString *)URLString length] == 0) {
            MixpanelError(@"invalid notification URL: %@", URLString);
            return nil;
        }

        callToActionURL = [NSURL URLWithString:(NSString *)URLString];
        if (callToActionURL == nil) {
            MixpanelError(@"invalid notification URL: %@", URLString);
            return nil;
        }
    }

    NSURL *imageURL = nil;
    NSString *imageURLString = object[@"image_url"];
    if (imageURLString != nil && ![imageURLString isKindOfClass:[NSNull class]]) {
        if (![imageURLString isKindOfClass:[NSString class]]) {
            MixpanelError(@"invalid notification image URL: %@", imageURLString);
            return nil;
        }
        
        NSURLComponents *components = [NSURLComponents componentsWithString:imageURLString];
        if ([components URL] == nil) {
            MixpanelError(@"unable to parse notification image URL componenets from string: %@", imageURLString);
            return nil;
        }

        if ([type isEqualToString:MPNotificationTypeTakeover]) {
            NSString *imageName = [imageURL.path stringByDeletingPathExtension];
            NSString *extension = [imageURL.path pathExtension];
            components.path = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
        }

        imageURL = [components URL];
        if (imageURL == nil) {
            MixpanelError(@"failed to encode notification image URL from components: %@", imageURLString);
            return nil;
        }
    }
    
    return [[MPNotification alloc] initWithID:[ID unsignedIntegerValue]
                                    messageID:[messageID unsignedIntegerValue]
                                         type:type
                                        title:title
                                         body:body
                                 callToAction:callToAction
                              callToActionURL:callToActionURL
                                     imageURL:imageURL];
}

- (instancetype)initWithID:(NSUInteger)ID messageID:(NSUInteger)messageID type:(NSString *)type title:(NSString *)title body:(NSString *)body callToAction:(NSString *)callToAction callToActionURL:(NSURL *)callToActionURL imageURL:(NSURL *)imageURL
{
    if (self = [super init]) {
        BOOL valid = YES;

        if (!(title && title.length > 0)) {
            valid = NO;
            MixpanelError(@"Notification title nil or empty: %@", title);
        }

        if (!(body && body.length > 0)) {
            valid = NO;
            MixpanelError(@"Notification body nil or empty: %@", body);
        }

        if (!([type isEqualToString:MPNotificationTypeTakeover] || [type isEqualToString:MPNotificationTypeMini])) {
            valid = NO;
            MixpanelError(@"Invalid notification type: %@, must be %@ or %@", type, MPNotificationTypeMini, MPNotificationTypeTakeover);
        }

        if (valid) {
            _ID = ID;
            _messageID = messageID;
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
            MixpanelError(@"image failed to load from URL: %@", _imageURL);
            return nil;
        }
        _image = imageData;
    }
    return _image;
}

@end
