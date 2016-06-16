#import "MPLogger.h"
#import "MPNotification.h"

NSString *const MPNotificationTypeMini = @"mini";
NSString *const MPNotificationTypeTakeover = @"takeover";

@implementation MPNotification

+ (MPNotification *)notificationWithJSONObject:(NSDictionary *)object
{
    if (object == nil) {
        MixpanelError(@"notif json object should not be nil");
        return nil;
    }

    NSNumber *ID = object[@"id"];
    if (!([ID isKindOfClass:[NSNumber class]] && ID.integerValue > 0)) {
        MixpanelError(@"invalid notif id: %@", ID);
        return nil;
    }

    NSNumber *messageID = object[@"message_id"];
    if (!([messageID isKindOfClass:[NSNumber class]] && messageID.integerValue > 0)) {
        MixpanelError(@"invalid notif message id: %@", messageID);
        return nil;
    }

    NSString *type = object[@"type"];
    if (![type isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notif type: %@", type);
        return nil;
    }
    
    NSString *style = object[@"style"];
    if (![style isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notif style: %@", style);
        return nil;
    }

    NSString *title = object[@"title"];
    if (![title isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notif title: %@", title);
        return nil;
    }

    NSString *body = object[@"body"];
    if (![body isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notif body: %@", body);
        return nil;
    }

    NSString *callToAction = object[@"cta"];
    if (![callToAction isKindOfClass:[NSString class]]) {
        MixpanelError(@"invalid notif cta: %@", callToAction);
        return nil;
    }

    NSURL *callToActionURL = nil;
    NSObject *URLString = object[@"cta_url"];
    if (URLString != nil && ![URLString isKindOfClass:[NSNull class]]) {
        if (![URLString isKindOfClass:[NSString class]] || [(NSString *)URLString length] == 0) {
            MixpanelError(@"invalid notif URL: %@", URLString);
            return nil;
        }

        callToActionURL = [NSURL URLWithString:(NSString *)URLString];
        if (callToActionURL == nil) {
            MixpanelError(@"invalid notif URL: %@", URLString);
            return nil;
        }
    }

    NSURL *imageURL = nil;
    NSString *imageURLString = object[@"image_url"];
    if (imageURLString != nil && ![imageURLString isKindOfClass:[NSNull class]]) {
        if (![imageURLString isKindOfClass:[NSString class]]) {
            MixpanelError(@"invalid notif image URL: %@", imageURLString);
            return nil;
        }
        NSString *escapedURLString = [imageURLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        imageURL = [NSURL URLWithString:escapedURLString];
        if (imageURL == nil) {
            MixpanelError(@"invalid notif image URL: %@", escapedURLString);
            return nil;
        }

        NSString *imagePath = imageURL.path;
        if ([type isEqualToString:MPNotificationTypeTakeover]) {
            NSString *imageName = [imagePath stringByDeletingPathExtension];
            NSString *extension = [imagePath pathExtension];
            imagePath = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
        }
        
        NSURLComponents *imageURLComponents = [[NSURLComponents alloc] init];
        imageURLComponents.scheme = imageURL.scheme;
        imageURLComponents.host = imageURL.host;
        imageURLComponents.path = imagePath;
        imageURL = imageURLComponents.URL;

        if (imageURL == nil) {
            MixpanelError(@"invalid notif image URL: %@", imageURLString);
            return nil;
        }
    }

    return [[MPNotification alloc] initWithID:ID.unsignedIntegerValue
                                    messageID:messageID.unsignedIntegerValue
                                         type:type
                                        style:style
                                        title:title
                                         body:body
                                 callToAction:callToAction
                              callToActionURL:callToActionURL
                                     imageURL:imageURL];
}

- (instancetype)initWithID:(NSUInteger)ID
                 messageID:(NSUInteger)messageID
                      type:(NSString *)type
                     style:(NSString *)style
                     title:(NSString *)title
                      body:(NSString *)body
              callToAction:(NSString *)callToAction
           callToActionURL:(NSURL *)callToActionURL
                  imageURL:(NSURL *)imageURL
{
    if (self = [super init]) {
        if (title.length == 0) {
            MixpanelError(@"Notification title nil or empty: %@", title);
            return nil;
        }

        if (body.length == 0) {
            MixpanelError(@"Notification body nil or empty: %@", body);
            return nil;
        }

        if (!([type isEqualToString:MPNotificationTypeTakeover] || [type isEqualToString:MPNotificationTypeMini])) {
            MixpanelError(@"Invalid notification type: %@, must be %@ or %@", type, MPNotificationTypeMini, MPNotificationTypeTakeover);
            return nil;
        }

        _ID = ID;
        _messageID = messageID;
        _type = type;
        _style = style;
        _title = title;
        _body = body;
        _imageURL = imageURL;
        _callToAction = callToAction;
        _callToActionURL = callToActionURL;
        _image = nil;
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
