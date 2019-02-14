#import "MPLogger.h"
#import "MPNotification.h"
#import "Mixpanel.h"
#import "MPNetworkPrivate.h"

NSString* const PROPERTY_EVAL_FUNC_NAME = @"evaluateFilters";
NSString* const PROPERTY_FILTERS_JS_URL = @"http://cdn-dev.mxpnl.com/libs/mixpanel.property-filters.dev.js";
@implementation MPNotification

#if !TARGET_OS_WATCH
+ (JSValue*) propertyFilterFunc {
    static JSValue* propertyFilterFunc = nil;
    static JSContext* jsContext = nil;
    
    if (propertyFilterFunc != nil) {
        return propertyFilterFunc;
    }
    
    jsContext = [[JSContext alloc] init];
    
    NSURL *url = [NSURL URLWithString:PROPERTY_FILTERS_JS_URL];
    [[[MPNetwork sharedURLSession] dataTaskWithURL:url completionHandler:^(NSData *responseData, NSURLResponse *urlResponse, NSError *error) {
        if (error) {
            MPLogError(@"error fetching property filters js snippet: %@", error);
            return;
        }
        
        NSString* script = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if (!script) {
            MPLogInfo(@"Error required property filters js snippet missing");
            return;
        }

        [jsContext setExceptionHandler:^(JSContext *context, JSValue *value) {
            MPLogError(@"Error executing JS: %@", value);
        }];
        
        [jsContext evaluateScript:script];
        propertyFilterFunc = jsContext[PROPERTY_EVAL_FUNC_NAME];
        BOOL out = [[propertyFilterFunc callWithArguments:@[@{@"operator": @"defined", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"prop1": @true}]] toBool];
        NSLog(@"%d", out);
        
    }] resume];
    
    return propertyFilterFunc;
}
#endif

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
        
        NSString *body = object[@"body"];
        if ([body isEqual:[NSNull null]]) {
            body = nil;
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
        
        id rawDisplayTriggers = object[@"display_triggers"];
        NSMutableArray *parsedDisplayTriggers = [NSMutableArray array];
        if (rawDisplayTriggers != nil && [rawDisplayTriggers isKindOfClass:[NSArray class]]) {
            for (id obj in rawDisplayTriggers) {
                MPDisplayTrigger *displayTrigger = [[MPDisplayTrigger alloc] initWithJSONObject:obj];
                [parsedDisplayTriggers addObject:displayTrigger];
            }
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
        _displayTriggers = parsedDisplayTriggers;
    }

    return self;
}

- (BOOL)hasDisplayTriggers {
    return self.displayTriggers != nil && [self.displayTriggers count] > 0;
}

- (BOOL)matchesEvent:(NSDictionary *)event {
    if ([self hasDisplayTriggers]) {
        for (id trigger in self.displayTriggers) {
            if([trigger matchesEvent:event]) {
                if ([[trigger filters] count] > 0) {
#if !TARGET_OS_WATCH
                    if (![MPNotification propertyFilterFunc]) {
                        MPLogError(@"Missing property filter function");
                        return NO;
                    }
                    return [[[MPNotification propertyFilterFunc] callWithArguments:@[[trigger filters], event[@"properties"]]] toBool];
#else
                    return NO;
#endif
                }
                return YES;
            }
        }
    }
    return NO;
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
