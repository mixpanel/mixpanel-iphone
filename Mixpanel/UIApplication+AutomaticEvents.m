//
//  UIApplication+AutomaticEvents.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIApplication+AutomaticEvents.h"
#import "Mixpanel+AutomaticEvents.h"
#import "MPSwizzle.h"
#import "MPLogger.h"

@implementation UIApplication (AutomaticEvents)

- (BOOL)mp_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    [[Mixpanel sharedAutomatedInstance] trackSendAction:action to:to from:from forEvent:event];
    return [self mp_sendAction:action to:to from:from forEvent:event];
}

- (void)mp_sendEvent:(UIEvent *)event {
    [[Mixpanel sharedAutomatedInstance] trackSendEvent:event];
    [self mp_sendEvent:event];
}

@end
