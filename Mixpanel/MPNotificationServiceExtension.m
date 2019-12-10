#import "MPNotificationServiceExtension.h"

static NSString *const kMediaUrlKey = @"mp_media_url";
static NSString *const kDynamicCategoryIdentifier = @"MP_DYNAMIC";

@interface MPNotificationServiceExtension()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *notificationContent;
@property BOOL richContentTaskComplete;
@property BOOL notificationCategoriesTaskComplete;

@end

@implementation MPNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler {
    
    self.contentHandler = contentHandler;
    self.notificationContent = [request.content mutableCopy];
    
    NSDictionary *userInfo = request.content.userInfo;
    if (userInfo == nil) {
        [self sendContent];
        return;
    }
    
    [self registerNotificationCategories:userInfo];
    [self attachRichMedia:userInfo];
}

- (void)serviceExtensionTimeWillExpire {
    [self sendContent];
}

- (void)taskComplete {
    NSLog(@"Task complete!");
    if (self.richContentTaskComplete && self.notificationCategoriesTaskComplete) {
        [self sendContent];
    }
}

- (void)sendContent {
    self.contentHandler(self.notificationContent);
}

- (void)registerNotificationCategories:(NSDictionary *) userInfo {
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *_Nonnull categories) {
        
        NSSet<UNNotificationCategory *> *filteredCategories = [categories objectsPassingTest:^BOOL(UNNotificationCategory *Nonnull category, BOOL *_Nonnull stop) {
            return ![[category identifier] containsString:kDynamicCategoryIdentifier];
        }];
        
        NSArray* buttons = userInfo[@"mp_buttons"];
        NSArray* actions = @[];
       __block NSArray* actions = @[];
        [buttons enumerateObjectsUsingBlock:^(NSDictionary *button, NSUInteger idx, BOOL *_Nonnull stop) {
            UNNotificationAction* action = [UNNotificationAction
                                            actionWithIdentifier:[NSString stringWithFormat:@"MP_ACTION_%lu", (unsigned long)idx]
                       title:button[@"lbl"]
                       options:UNNotificationActionOptionForeground];
            actions = [actions arrayByAddingObject:action];
        }];
        for (NSDictionary* button in buttons) {
            UNNotificationAction* action = [UNNotificationAction
                       actionWithIdentifier:[NSString stringWithFormat:@"MP_ACTION_%d", i]
                       title:button[@"lbl"]
                       options:UNNotificationActionOptionForeground];
            actions = [actions arrayByAddingObject:action];
            i++;
        }

        UNNotificationCategory* mpDynamicCategory = [UNNotificationCategory
            categoryWithIdentifier:kDynamicCategoryIdentifier
            actions:actions
            intentIdentifiers:@[]
            options:UNNotificationCategoryOptionNone];
        
        NSSet<UNNotificationCategory *>* finalCategory = [filtered setByAddingObject:mpDynamicCategory];
        
        [center setNotificationCategories:final];
        
        self.notificationCategoriesTaskComplete = true;
        
        [self taskComplete];

        NSLog(@"Setup notification categories");
    }];
}

- (void)attachRichMedia:(NSDictionary *) userInfo {

    NSString *mediaUrlKey = self.mediaUrlKey ? self.mediaUrlKey : kMediaUrlKey;
    NSString *mediaUrl = userInfo[mediaUrlKey];
    NSString *mediaType = [mediaUrl pathExtension];
    
    if (mediaUrl == nil || mediaType == nil) {
#ifdef DEBUG
        if (mediaUrl == nil) {
             NSLog(@"unable to add attachment: %@ is nil", mediaUrlKey);
        }
        
        if (mediaType == nil) {
            NSLog(@"unable to add attachment: extension is nil");
        }
#endif
        self.richContentTaskComplete = true;
        [self taskComplete];
        return;
    }
    
    // load the attachment
    [self loadAttachmentForUrlString:mediaUrl
                            withType:mediaType
                   completionHandler:^(UNNotificationAttachment *attachment) {
                        if (attachment) {
                            self.notificationContent.attachments = [NSArray arrayWithObject:attachment];
                        }
                        self.richContentTaskComplete = true;
                        [self taskComplete];
                   }];
}
- (void)loadAttachmentForUrlString:(NSString *)urlString withType:(NSString *)type
                 completionHandler:(void(^)(UNNotificationAttachment *))completionHandler  {
    
    __block UNNotificationAttachment *attachment = nil;
    NSURL *attachmentURL = [NSURL URLWithString:urlString];
    NSString *fileExt = [@"." stringByAppendingString:type];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:attachmentURL
                completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
                    if (error != nil) {
                        #ifdef DEBUG
                        NSLog(@"unable to add attachment: %@", error.localizedDescription);
                        #endif
                    } else {
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExt]];
                        [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
                        
                        NSError *attachmentError = nil;
                        attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:localURL options:nil error:&attachmentError];
                        if (attachmentError) {
                            #ifdef DEBUG
                            NSLog(@"unable to add attchment: %@", attachmentError.localizedDescription);
                            #endif
                        }
                    }
                    completionHandler(attachment);
                }] resume];
}

@end
