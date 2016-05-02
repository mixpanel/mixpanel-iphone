#import <UIKit/UIKit.h>
@import Mixpanel;

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, MixpanelDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) Mixpanel *mixpanel;

@property (strong, nonatomic, retain) NSDate *startTime;

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end
