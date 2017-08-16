#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
@import Mixpanel;

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, MixpanelDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) Mixpanel *mixpanel;

@property (strong, nonatomic, retain) NSDate *startTime;

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end
