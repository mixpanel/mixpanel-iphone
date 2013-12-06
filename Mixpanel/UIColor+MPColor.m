//
//  UIColor+MPColor.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 22/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "UIColor+MPColor.h"

@implementation UIColor (MPColor)

+ (UIColor *)applicationPrimaryColor
{

    UIColor *color;

    // First try and find the color of the UINavigationBar of the top UINavigationBar that is showing now.
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UINavigationController *topNavigationController = nil;

    do {
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            topNavigationController = (UINavigationController *)rootViewController;
        } else if (rootViewController.navigationController) {
            topNavigationController = rootViewController.navigationController;
        }
    } while ((rootViewController = rootViewController.presentedViewController));

    if (topNavigationController) {
        //REVIEW reminder: tint color stuff needs to be protected in ios 6
        color = [[topNavigationController navigationBar] barTintColor];
    }

    // Then try and use the UINavigationBar default color for the app
    if (!color) {
        color = [[UINavigationBar appearance] barTintColor];
    }

    // Or the UITabBar default color
    if (!color) {
        color = [[UITabBar appearance] barTintColor];
    }

    return color;
}

+ (UIColor *)lightEffectColor
{
    return [UIColor colorWithWhite:1.0f alpha:0.3f];
}

+ (UIColor *)extraLightEffectColor
{
    return [UIColor colorWithWhite:0.97f alpha:0.82f];
}

+ (UIColor *)darkEffectColor
{
    return [UIColor colorWithWhite:0.11f alpha:0.73f];
}

- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation
{
    UIColor *newColor;
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
        newColor = [UIColor colorWithHue:h saturation:saturation brightness:b alpha:a];
    }
    return newColor;
}

@end
