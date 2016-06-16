#import "UIColor+MPColor.h"

@implementation UIColor (MPColor)

+ (UIColor *)mp_applicationPrimaryColor
{
    // First try and find the color of the UINavigationBar of the top UINavigationController that is showing now.
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UINavigationController *topNavigationController = nil;

    do {
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            topNavigationController = (UINavigationController *)rootViewController;
        } else if (rootViewController.navigationController) {
            topNavigationController = rootViewController.navigationController;
        }
    } while ((rootViewController = rootViewController.presentedViewController));

    UIColor *color = [topNavigationController navigationBar].barTintColor;

    // Then try and use the UINavigationBar default color for the app
    if (!color) {
        color = [UINavigationBar appearance].barTintColor;
    }

    // Or the UITabBar default color
    if (!color) {
        color = [UITabBar appearance].barTintColor;
    }

    return color;
}

+ (UIColor *)mp_lightEffectColor
{
    return [UIColor colorWithWhite:1.0f alpha:0.3f];
}

+ (UIColor *)mp_extraLightEffectColor
{
    return [UIColor colorWithWhite:0.97f alpha:0.82f];
}

+ (UIColor *)mp_darkEffectColor
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
