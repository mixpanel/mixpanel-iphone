#import "MPNotification.h"

@protocol MPNotificationViewControllerDelegate;

@interface MPNotificationViewController : UIViewController

@property (nonatomic, strong) MPNotification *notification;
@property (nonatomic, weak) id<MPNotificationViewControllerDelegate> delegate;

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion;

@end

@interface MPTakeoverNotificationViewController : MPNotificationViewController

@property (nonatomic, strong) UIImage *backgroundImage;

@end

@interface MPMiniNotificationViewController : MPNotificationViewController

@property (nonatomic, strong) UIColor *backgroundColor;

- (void)showWithAnimation;

@end

@protocol MPNotificationViewControllerDelegate <NSObject>

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithStatus:(BOOL)status;

@end
