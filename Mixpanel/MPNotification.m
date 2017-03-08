#import "MPLogger.h"
#import "MPNotification.h"

NSString *const MPNotificationTypeMini = @"mini";
NSString *const MPNotificationTypeTakeover = @"takeover";

@implementation MPNotification

- (instancetype)initWithJSONObject:(NSDictionary *)object {
    if (self = [super init]) {
        if (object == nil) {
            MPLogError(@"notif json object should not be nil");
            return nil;
        }
        
        NSNumber *ID = object[@"id"];
        if (!([ID isKindOfClass:[NSNumber class]] && ID.integerValue > 0)) {
            [MPNotification logNotificationError:@"id" withValue:ID];
            return nil;
        }
        
        NSNumber *messageID = object[@"message_id"];
        if (!([messageID isKindOfClass:[NSNumber class]] && messageID.integerValue > 0)) {
            [MPNotification logNotificationError:@"message" withValue:messageID];
            return nil;
        }
        
        NSString *body;
        if (object[@"body"] != [NSNull null]) {
            body = object[@"body"];
        }
        
        if (!(body == nil || [body isKindOfClass:[NSString class]])) {
            [MPNotification logNotificationError:@"body" withValue:body];
            return nil;
        }
        
        NSNumber *bodyColor = object[@"body_color"];
        if (!([bodyColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"body color" withValue:bodyColor];
            return nil;
        }
        
        NSNumber *backgroundColor = object[@"bg_color"];
        if (!([backgroundColor isKindOfClass:[NSNumber class]])) {
            [MPNotification logNotificationError:@"background color" withValue:bodyColor];
            return nil;
        }
        
        NSURL *imageURL = nil;
        NSString *imageURLString = object[@"image_url"];
        if (imageURLString != nil && ![imageURLString isKindOfClass:[NSNull class]]) {
            if (![imageURLString isKindOfClass:[NSString class]]) {
                [MPNotification logNotificationError:@"image url" withValue:imageURLString];
                return nil;
            }
            
            NSString *escapedURLString = [imageURLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            imageURL = [NSURL URLWithString:escapedURLString];
            if (imageURL == nil) {
                [MPNotification logNotificationError:@"image url" withValue:escapedURLString];
                return nil;
            }
            
            NSString *imagePath = imageURL.path;
            if ([self.type isEqualToString:MPNotificationTypeTakeover]) {
                NSString *imageName = [imagePath stringByDeletingPathExtension];
                NSString *extension = [imagePath pathExtension];
                imagePath = [[imageName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:extension];
            }
            
            NSURLComponents *imageURLComponents = [[NSURLComponents alloc] init];
            imageURLComponents.scheme = imageURL.scheme;
            imageURLComponents.host = imageURL.host;
            imageURLComponents.path = imagePath;
            
            if (imageURLComponents.URL == nil) {
                [MPNotification logNotificationError:@"image url" withValue:imageURLString];
                return nil;
            }
            imageURL = imageURLComponents.URL;
        } else {
            [MPNotification logNotificationError:@"image url" withValue:imageURLString];
            return nil;
        }
        
        _jsonDescription = object;
        _extrasDescription = object[@"extras"];
        _ID = ID.unsignedIntegerValue;
        _messageID = messageID.unsignedIntegerValue;
        _body = body;
        _bodyColor = bodyColor.unsignedIntegerValue;
        _backgroundColor = backgroundColor.unsignedIntegerValue;
        _imageURL = imageURL;
        _image = nil;
    }

    return self;
}

- (NSString *)type {
    NSAssert(false, @"Sub-classes must override this method");
    return nil;
}

- (NSData *)image {
    if (_image == nil && _imageURL != nil) {
        NSError *error = nil;
        NSData *imageData = [NSData dataWithContentsOfURL:_imageURL options:NSDataReadingMappedIfSafe error:&error];
        if (error || !imageData) {
            MPLogError(@"image failed to load from URL: %@", _imageURL);
            return nil;
        }
        _image = imageData;
    }
    return _image;
}

+ (void)logNotificationError:(NSString *)field withValue:(id)value {
    MPLogError(@"Invalid notification %@: %@", field, value);
}

@end
