//
//  UIColor+MPColor.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 22/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (MPColor)

+ (UIColor *)applicationPrimaryColor;

+ (UIColor *)lightEffectColor;
+ (UIColor *)extraLightEffectColor;
+ (UIColor *)darkEffectColor;

- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation;

@end
