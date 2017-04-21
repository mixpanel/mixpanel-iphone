//
//  NSNotificationCenter+AutomaticTracks.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNotificationCenter (AutomaticTracks)

- (void)mp_postNotification:(NSNotification *)notification;

- (void)mp_postNotificationName:(NSString *)name
                         object:(nullable id)object
                       userInfo:(nullable NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
