//
//  UIApplication+AutomaticEvents.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIApplication+AutomaticEvents.h"
#import "Mixpanel+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"

@implementation UIApplication (AutomaticEvents)

- (BOOL)mp_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    [[Mixpanel sharedAutomatedInstance] track:kAutomaticEventName];
    return [self mp_sendAction:action to:to from:from forEvent:event];
}

@end
