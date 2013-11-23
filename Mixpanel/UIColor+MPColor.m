//
//  UIColor+MPColor.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 22/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "UIColor+MPColor.h"

@implementation UIColor (MPColor)

+(UIColor *)applicationPrimaryColor
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

+(UIColor *)applicationPrimaryColorWithAlpha:(CGFloat) alpha
{
    UIColor *color = [self applicationPrimaryColor];
    CGFloat r, g, b, a;
    if (color && [color getRed:&r green:&g blue:&b alpha:&a]) {
        color = [UIColor colorWithRed:r green:g blue:b alpha:alpha];
    }
    return color;
}

+(UIColor *)lightEffectColor
{
    return [UIColor colorWithWhite:1.0f alpha:0.3f];
}

+(UIColor *)extraLightEffectColor
{
    return [UIColor colorWithWhite:0.97f alpha:0.82f];
}

+(UIColor *)darkEffectColor
{
    return [UIColor colorWithWhite:0.11f alpha:0.73f];
}



@end
