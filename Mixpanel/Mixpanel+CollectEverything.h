//
//  Mixpanel+CollectEverything.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"

@interface Mixpanel (CollectEverything)

+ (instancetype)internalMixpanel;
+ (void)addSwizzles;

#pragma mark - UIApplication
- (void)trackSendEvent:(UIEvent *)event;
- (void)trackSendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event;

#pragma mark - UIViewController
- (void)trackViewControllerAppeared:(UIViewController *)viewController;

#pragma mark - NSNotification
- (void)trackNotification:(NSNotification *)notification;
- (void)trackNotificationName:(NSString *)name object:(id)object;
- (void)trackNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)info;

@end
