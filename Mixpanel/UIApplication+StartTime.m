//
//  UIApplication+StartTime.m
//  Mixpanel
//
//  Created by Yarden Eitan on 4/21/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "UIApplication+StartTime.h"
#import "AutomaticEvents.h"

@implementation UIApplication (StartTime)

+ (void) load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AutomaticEvents.appStartTime = [[NSDate date] timeIntervalSince1970];
    });
}

@end
