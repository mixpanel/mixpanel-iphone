//
//  UIApplication+CollectEverything.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIApplication+CollectEverything.h"
#import "Mixpanel+CollectEverything.h"
#import "MPSwizzle.h"
#import "MPLogger.h"

@implementation UIApplication (CollectEverything)

- (BOOL)mp_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    [[Mixpanel internalMixpanel] trackSendAction:action to:to from:from forEvent:event];
    return [self mp_sendAction:action to:to from:from forEvent:event];
}

- (void)mp_sendEvent:(UIEvent *)event {
    [[Mixpanel internalMixpanel] trackSendEvent:event];
    [self mp_sendEvent:event];
}

@end
