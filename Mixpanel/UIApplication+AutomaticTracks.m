//
//  UIApplication+AutomaticTracks.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "UIApplication+AutomaticTracks.h"
#import "Mixpanel+AutomaticTracks.h"
#import "AutomaticTracksConstants.h"

@implementation UIApplication (AutomaticTracks)

- (BOOL)mp_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    [[Mixpanel sharedAutomatedInstance] track:kAutomaticTrackName];
    return [self mp_sendAction:action to:to from:from forEvent:event];
}

@end
