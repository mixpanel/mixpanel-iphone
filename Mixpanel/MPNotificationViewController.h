#import "MPTakeoverNotification.h"
#import "MPMiniNotification.h"

@protocol MPNotificationViewControllerDelegate;

@interface MPNotificationViewController : UIViewController

@property (nonatomic, weak) id<MPNotificationViewControllerDelegate> delegate;
@property (nonatomic, strong) MPNotification *notification;

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion;

@end

@interface MPTakeoverNotificationViewController : MPNotificationViewController

@end

@interface MPMiniNotificationViewController : MPNotificationViewController

- (void)showWithAnimation;

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithCtaUrl:(NSURL *)ctaUrl;

@end
