//
//  UIApplication+AutomaticTracks.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (AutomaticTracks)

- (BOOL)mp_sendAction:(SEL)action
                   to:(nullable id)to
                 from:(nullable id)from
             forEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
