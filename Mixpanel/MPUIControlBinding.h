//
//  MPUIControlBinding.h
//  HelloMixpanel
//
//  Created by Amanda Canyon on 8/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPEventBinding.h"

@interface MPUIControlBinding : MPEventBinding

@property (nonatomic, readonly) UIControlEvents controlEvent;
@property (nonatomic, readonly) UIControlEvents verifyEvent;


/*!
 @method

 @abstract
 Fired internally as the Action of a Target/Action pair

 @discussion
 This method will be bound to each UIControl selected by
 path as a Target/Action pair. It is responsible for firing
 the related mixpanel event.
 */
- (void)execute:(id)sender forEvent:(UIEvent *)event;
- (id)initWithEventName:(NSString *)eventName
                 onPath:(NSString *)path
       withControlEvent:(UIControlEvents)controlEvent
         andVerifyEvent:(UIControlEvents)verifyEvent;

@end
