//
//  UIApplication+CollectEverything.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIApplication (CollectEverything)

- (BOOL)mp_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event;
- (void)mp_sendEvent:(UIEvent *)event;

@end
