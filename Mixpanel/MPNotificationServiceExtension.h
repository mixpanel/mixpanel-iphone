#import <UserNotifications/UserNotifications.h>

@interface MPNotificationServiceExtension : UNNotificationServiceExtension

@property (nonatomic, copy, readonly, nullable) NSString *mediaUrlKey;

NS_ASSUME_NONNULL_BEGIN

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *Nonnull))contentHandler;

@end

NS_ASSUME_NONNULL_END
