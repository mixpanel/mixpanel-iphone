//
//  AppDelegate.h
//  tvOS_Example
//
//  Created by Yarden Eitan on 5/31/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Mixpanel;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) Mixpanel *mixpanel;
@property (strong, nonatomic, retain) NSDate *startTime;

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;
@property (strong, nonatomic) UIWindow *window;


@end

