#import "MPNotificationServiceExtension.h"
#import "MPLogger.h"
#import "Mixpanel.h"

#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT

@interface MPNotificationServiceExtension()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation MPNotificationServiceExtension


- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler  {
    NSLog(@"%@ MPNotificationServiceExtension didReceiveNotificationRequest", self);

    if (![Mixpanel isMixpanelPushNotification:request.content]) {
        NSLog(@"%@ Not a Mixpanel push notification, returning original content", self);
        contentHandler(request.content);
        return;
    }

    // Store a reference to the mutable content and the contentHandler on the class so we
    // can use them in serviceExtensionTimeWillExpire if needed
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    // Track $push_notification_received event
    [Mixpanel trackPushNotificationEventFromRequest:request event:@"$push_notification_received" properties:@{}];

    // Setup the category first since it's faster and less likely to cause time to expire
    [self getCategoryIdentifier:request.content withCompletion:^(NSString *categoryIdentifier) {
        NSLog(@"%@ Using \"%@\" as categoryIdentifier", self, categoryIdentifier);

        self.bestAttemptContent.categoryIdentifier = categoryIdentifier;
        // Download rich media and create an attachment
        [self buildAttachments:request.content withCompletion:^(NSArray *attachments){
            if (attachments) {
                NSLog(@"%@ Added %lu attachment(s)", self, (unsigned long)[attachments count]);
                self.bestAttemptContent.attachments = attachments;
            } else {
                NSLog(@"%@ No rich media found to attach", self);
            }

            NSLog(@"%@ Notification finished building, returning content", self);
            self.contentHandler(self.bestAttemptContent);

        }];
    }];
}

- (void)serviceExtensionTimeWillExpire {
    NSLog(@"%@ contentHandler not called in time, returning bestAttemptContent", self);
    self.contentHandler(self.bestAttemptContent);
}

- (void)getCategoryIdentifier:(UNNotificationContent *) content
               withCompletion:(void(^)(NSString *categoryIdentifier))completion {
    // If the payload explicitly specifies a category, use it
    if ([content.categoryIdentifier length] > 0) {
        NSLog(@"%@ getCategoryIdentifier: explicit categoryIdentifer included in payload: %@", self, content.categoryIdentifier);
        completion(content.categoryIdentifier);
        return;
    }

    NSDictionary *userInfo = content.userInfo;
    if (userInfo == nil) {
        NSLog(@"%@ getCategoryIdentifier: content.userInfo was nil, not creating action buttons.", self);
        completion(nil);
        return;
    }

    // Generate unique category id from timestamp
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
    NSString *categoryId = [timeStampObj stringValue];

    // Get buttons if they are specified
    NSArray *buttons = userInfo[@"mp_buttons"];
    if (buttons == nil) {
        NSLog(@"%@ getCategoryIdentifier: nothing specified under \"mp_buttons\" key, not creating action buttons.", self);
        buttons = @[];
    }

    // Build a list of actions from the buttons data
    __block NSArray* actions = @[];
    [buttons enumerateObjectsUsingBlock:^(NSDictionary *button, NSUInteger idx, BOOL *_Nonnull stop) {
        UNNotificationAction* action = [UNNotificationAction
                                        actionWithIdentifier:[NSString stringWithFormat:@"MP_ACTION_%lu", (unsigned long)idx]
                                        title:button[@"lbl"]
                                        options:UNNotificationActionOptionForeground];
        actions = [actions arrayByAddingObject:action];
    }];

    // Create a new category with custom dismiss action set to true and any action buttons specified
    UNNotificationCategory *newCategory = [UNNotificationCategory
                                           categoryWithIdentifier:categoryId
                                           actions:actions
                                           intentIdentifiers:@[]
                                           options:UNNotificationCategoryOptionCustomDismissAction];

    NSLog(@"%@ getCategoryIdentifier: Created a new category \"%@\" with %lu action button(s)", self, categoryId, (unsigned long)[actions count]);

    // Add the new category
    [center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *_Nonnull categories) {
        [center setNotificationCategories:[categories setByAddingObject:newCategory]];

        // In testing, it's clear that setNotificationCategories is not a synchronous action
        // or there is caching going on. We need to wait until the category is available.
        [self waitForCategoryExistence:categoryId withCompletion:^{
            NSLog(@"%@ waitForCategoryExistence: Category \"%@\" found, returning.", self, categoryId);
            completion(categoryId);
        }];
    }];

}

- (void)waitForCategoryExistence:(NSString *) categoryIdentifier withCompletion:(void(^)(void))completion {
    NSLog(@"%@ Checking for the existence of category \"%@\"...", self, categoryIdentifier);
    [UNUserNotificationCenter.currentNotificationCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *_Nonnull categories) {
        for(UNNotificationCategory *category in categories) {
            if ([category.identifier isEqualToString:categoryIdentifier]) {
                completion();
                return;
            }
        }
        [self waitForCategoryExistence:categoryIdentifier withCompletion:completion];
    }];
}

- (void)buildAttachments:(UNNotificationContent *) content withCompletion:(void(^)(NSArray *))completion {
    NSDictionary *userInfo = content.userInfo;
    if (userInfo == nil) {
        NSLog(@"%@ buildAttachments: content.userInfo was nil, not creating action buttons.", self);
        completion(nil);
        return;
    }

    NSString *mediaUrl = userInfo[@"mp_media_url"];
    if (mediaUrl == nil) {
        NSLog(@"%@ buildAttachments: No media url specified, not attatching rich media", self);
        completion(nil);
        return;
    }

    NSString *mediaType = [mediaUrl pathExtension];
    if (mediaType == nil) {
        NSLog(@"%@ buildAttachments: Unable to add attachment: extension is nil", self);
        completion(nil);
        return;
    }

    [self loadAttachmentForUrlString:mediaUrl
                            withType:mediaType
                      withCompletion:^(UNNotificationAttachment *attachment) {
        completion([NSArray arrayWithObject:attachment]);
    }];
}

- (void)loadAttachmentForUrlString:(NSString *)urlString
                          withType:(NSString *)type
                    withCompletion:(void(^)(UNNotificationAttachment *))completion  {
    __block UNNotificationAttachment *attachment = nil;
    NSURL *attachmentURL = [NSURL URLWithString:urlString];
    NSString *fileExt = [@"." stringByAppendingString:type];

    NSLog(@"%@ Attempting download of media from url: %@", self, urlString);

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:attachmentURL
                completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
                    if (error != nil) {
                        NSLog(@"%@ loadAttachmentForUrlString: Unable to add attachment: %@", self, error.localizedDescription);
                    } else {
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExt]];
                        [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
                        
                        NSError *attachmentError = nil;
                        attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:localURL options:nil error:&attachmentError];
                        if (attachmentError || !attachment) {
                            NSLog(@"%@ loadAttachmentForUrlString: Unable to add attachment: %@", self, attachmentError.localizedDescription);
                        } else {
                            NSLog(@"%@ loadAttachmentForUrlString: Successfully created attachment from url: %@", self, attachmentURL);
                        }
                    }
                    completion(attachment);
                }] resume];
}

@end

#endif
