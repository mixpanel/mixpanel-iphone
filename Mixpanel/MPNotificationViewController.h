#import "MPTakeoverNotification.h"
#import "MPMiniNotification.h"

@protocol MPNotificationViewControllerDelegate;

@interface MPNotificationViewController : UIViewController

@property (nonatomic, weak) id<MPNotificationViewControllerDelegate> delegate;
@property (nonatomic, strong) MPNotification *notification;

- (void)show;
- (void)hide:(BOOL)animated completion:(void (^)(void))completion;

@end

@interface MPTakeoverNotificationViewController : MPNotificationViewController

@end

@interface MPMiniNotificationViewController : MPNotificationViewController

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithCtaUrl:(NSURL *)ctaUrl;

@end
