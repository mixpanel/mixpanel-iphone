//
//  AppDelegate.h
//  tvOS_Example
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Mixpanel;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) Mixpanel *mixpanel;
@property (strong, nonatomic, retain) NSDate *startTime;

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;
@property (strong, nonatomic) UIWindow *window;


@end

