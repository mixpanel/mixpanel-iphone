//
//  NSNotificationCenter+AutomaticTracks.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "NSNotificationCenter+AutomaticTracks.h"
#import "Mixpanel+AutomaticTracks.h"
#import "AutomaticTracksConstants.h"

@implementation NSNotificationCenter (AutomaticTracks)

- (void)mp_postNotification:(NSNotification *)notification {
    if ([NSNotificationCenter shouldTrackNotificationNamed:notification.name]) {
        [[Mixpanel sharedAutomatedInstance] track:kAutomaticTrackName];
    }
    
    [self mp_postNotification:notification];
}

- (void)mp_postNotificationName:(NSString *)name
                         object:(nullable id)object
                       userInfo:(nullable NSDictionary *)info {
    if ([NSNotificationCenter shouldTrackNotificationNamed:name]) {
        [[Mixpanel sharedAutomatedInstance] track:kAutomaticTrackName];
    }
    
    [self mp_postNotificationName:name object:object userInfo:info];
}

+ (BOOL)shouldTrackNotificationNamed:(NSString *)name {
    // iOS spams notifications. We're whitelisting for now.
    NSArray *names = @[
                       // UITextField Editing
                       UITextFieldTextDidEndEditingNotification,
                       
                       // UIApplication Lifecycle
                       UIApplicationDidFinishLaunchingNotification,
                       UIApplicationDidEnterBackgroundNotification,
                       UIApplicationDidBecomeActiveNotification ];
    NSSet<NSString *> *whiteListedNotificationNames = [NSSet setWithArray:names];
    return [whiteListedNotificationNames containsObject:name];
}

@end
