#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPNotificationServiceExtension : UNNotificationServiceExtension

@property (nonatomic, copy, readonly, nullable) NSString *mediaUrlKey;


- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *Nonnull))contentHandler;

@end

NS_ASSUME_NONNULL_END
