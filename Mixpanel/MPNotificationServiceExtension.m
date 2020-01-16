#import "MPNotificationServiceExtension.h"
#import "MPLogger.h"

static NSString *const mediaUrlKey = @"mp_media_url";

API_AVAILABLE(ios(10.0))
@interface MPNotificationServiceExtension()

@end

@implementation MPNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler  {

    NSLog(@"%@ MPNotificationServiceExtension didReceiveNotificationRequest", self);

    UNMutableNotificationContent *bestAttemptContent = [request.content mutableCopy];
    [self getCategoryIdentifier:request.content withCompletion:^(NSString *categoryIdentifier) {

        NSLog(@"%@ Using \"%@\" as categoryIdentifier", self, categoryIdentifier);
        bestAttemptContent.categoryIdentifier = categoryIdentifier;

        [self buildAttachments:request.content withCompletion:^(NSArray *attachments){
            if (attachments) {
                NSLog(@"%@ Added rich media attachment", self);
                bestAttemptContent.attachments = attachments;
            } else {
                NSLog(@"%@ No rich media found to attach", self);
            }
            contentHandler(bestAttemptContent);
        }];

    }];
}

- (void)getCategoryIdentifier:(UNNotificationContent *) content
               withCompletion:(void(^)(NSString *categoryIdentifier))completion {

    // If the payload explicitly specifies a category, just use that one
    if (content.categoryIdentifier != nil) {
        completion(content.categoryIdentifier);
        return;
    }

    NSDictionary *userInfo = content.userInfo;
    if (userInfo == nil) {
        completion(nil);
        return;
    }

    NSArray* buttons = userInfo[@"mp_buttons"];
    if (buttons == nil) {
        completion(nil);
        return;
    }

    // Generate dynamic category id
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
    NSString *categoryId = [timeStampObj stringValue];

    [center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *_Nonnull categories) {

        // Generate a list of actions from the buttons data
        __block NSArray* actions = @[];
        [buttons enumerateObjectsUsingBlock:^(NSDictionary *button, NSUInteger idx, BOOL *_Nonnull stop) {
            UNNotificationAction* action = [UNNotificationAction
                                            actionWithIdentifier:[NSString stringWithFormat:@"MP_ACTION_%lu", (unsigned long)idx]
                                            title:button[@"lbl"]
                                            options:UNNotificationActionOptionForeground];
            actions = [actions arrayByAddingObject:action];
        }];

        // Create a new category for these actions
        UNNotificationCategory* newCategory = [UNNotificationCategory
                                                     categoryWithIdentifier:categoryId
                                                     actions:actions
                                                     intentIdentifiers:@[]
                                                     options:UNNotificationCategoryOptionNone];
      
        // Add the new category
        [center setNotificationCategories:[categories setByAddingObject:newCategory]];

        completion(categoryId);
    }];

    return;
}

- (void)buildAttachments:(UNNotificationContent *) content withCompletion:(void(^)(NSArray *))completion {

    NSDictionary *userInfo = content.userInfo;
    if (userInfo == nil) {
        completion(nil);
        return;
    }

    NSString *mediaUrl = userInfo[mediaUrlKey];
    if (mediaUrl == nil) {
        NSLog(@"%@ No media url specified, not attatching rich media", self);
        completion(nil);
        return;
    }

    NSString *mediaType = [mediaUrl pathExtension];
    if (mediaType == nil) {
        NSLog(@"%@ unable to add attachment: extension is nil", self);
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

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:attachmentURL
                completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
                    if (error != nil) {
                        NSLog(@"%@ unable to add attachment: %@", self, error.localizedDescription);
                    } else {
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExt]];
                        [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
                        
                        NSError *attachmentError = nil;
                        attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:localURL options:nil error:&attachmentError];
                        if (attachmentError || !attachment) {
                            NSLog(@"%@ unable to add attachment: %@", self, attachmentError.localizedDescription);
                        }
                    }
                    completion(attachment);
                }] resume];
}

@end
