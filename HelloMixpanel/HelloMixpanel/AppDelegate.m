@import Mixpanel;
#import "AppDelegate.h"
#import "ViewController.h"

// IMPORTANT!!! replace with your api token from https://mixpanel.com/account/
#define MIXPANEL_TOKEN @"YOUR_MIXPANEL_PROJECT_TOKEN"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"mixpanelToken": MIXPANEL_TOKEN}];
    NSString *mixpanelToken = [[NSUserDefaults standardUserDefaults] stringForKey:@"mixpanelToken"];

    [self.window makeKeyAndVisible];

    if (mixpanelToken == nil || [mixpanelToken isEqualToString:@""] || [mixpanelToken isEqualToString:@"YOUR_MIXPANEL_PROJECT_TOKEN"]) {
#ifndef DEBUG
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Mixpanel Token Required" message:@"Go to Settings > Mixpanel and add your project's token" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
#endif
    } else {
        // Initialize the MixpanelAPI object
        self.mixpanel = [Mixpanel sharedInstanceWithToken:mixpanelToken launchOptions:launchOptions];
    }

    // Override point for customization after application launch.

    self.mixpanel.checkForNotificationsOnActive = YES;
    self.mixpanel.showNotificationOnActive = YES; //Change this to NO to show your notifs manually.
    self.mixpanel.enableLogging = YES;
    
    // Set the upload interval to 20 seconds for demonstration purposes. This would be overkill for most applications.
    self.mixpanel.flushInterval = 20; // defaults to 60 seconds
    
    // Set some super properties, which will be added to every tracked event
    [self.mixpanel registerSuperProperties:@{@"Plan": @"Premium"}];

    if ([UNUserNotificationCenter class]) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
            }
        }];
    }

    return YES;
}

#pragma mark - Push notifications

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    if ([response.actionIdentifier isEqualToString:@"declineAction"]) {
        NSLog(@"%@ user declined push notification action", self);
        
    } else if ([response.actionIdentifier isEqualToString:@"answerAction"]) {
        NSLog(@"%@ user answered push notification action", self);
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:response.notification.request.content.userInfo[@"aps"][@"alert"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay") style:UIAlertActionStyleDefault handler:nil]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    
    completionHandler();
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    [self.mixpanel.people addPushDeviceToken:devToken];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"%@ push registration error is expected on simulator", self);
#else
    NSLog(@"%@ push registration error: %@", self, err);
#endif
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
}


#pragma mark - Session timing example

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    self.startTime = [NSDate date];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"%@ will resign active", self);
    NSNumber *seconds = @([[NSDate date] timeIntervalSinceDate:self.startTime]);
    [[Mixpanel sharedInstance] track:@"Session" properties:@{@"Length": seconds}];
}

#pragma mark - Background task tracking test

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    self.bgTask = [application beginBackgroundTaskWithExpirationHandler:^{

        NSLog(@"%@ background task %lu cut short", self, (unsigned long)self.bgTask);

        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSLog(@"%@ starting background task %lu", self, (unsigned long)self.bgTask);

        // track some events and set some people properties
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel registerSuperProperties:@{@"Background Super Property": @"Hi!"}];
        [mixpanel track:@"Background Event"];
        [mixpanel.people set:@"Background Property" to:[NSDate date]];

        NSLog(@"%@ ending background task %lu", self, (unsigned long)self.bgTask);
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    });

    NSLog(@"%@ dispatched background task %lu", self, (unsigned long)self.bgTask);
}

@end
