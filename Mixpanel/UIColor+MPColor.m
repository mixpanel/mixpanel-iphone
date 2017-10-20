#import "MixpanelPrivate.h"
#import "UIColor+MPColor.h"

@implementation UIColor (MPColor)

+ (UIColor *)mp_applicationPrimaryColor {
    // First try and find the color of the UINavigationBar of the top UINavigationController that is showing now.
    UIViewController *rootViewController = [Mixpanel sharedUIApplication].keyWindow.rootViewController;
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

+ (UIColor *)mp_lightEffectColor {
    return [UIColor colorWithWhite:1.0f alpha:0.3f];
}

+ (UIColor *)mp_extraLightEffectColor {
    return [UIColor colorWithWhite:0.97f alpha:0.82f];
}

+ (UIColor *)mp_darkEffectColor {
    return [UIColor colorWithWhite:0.11f alpha:0.73f];
}

+ (UIColor *)mp_colorFromRGB:(NSUInteger)rgbValue {
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0];
}

- (UIColor *)mp_colorAddColor:(UIColor *)overlay {
    CGFloat bgR = 0;
    CGFloat bgG = 0;
    CGFloat bgB = 0;
    CGFloat bgA = 0;

    CGFloat fgR = 0;
    CGFloat fgG = 0;
    CGFloat fgB = 0;
    CGFloat fgA = 0;


    [self getRed:&bgR green: &bgG blue: &bgB alpha: &bgA];
    [overlay getRed:&fgR green: &fgG blue: &fgB alpha: &fgA];

    CGFloat r = fgA * fgR + (1 - fgA) * bgR;
    CGFloat g = fgA * fgG + (1 - fgA) * bgG;
    CGFloat b = fgA * fgB + (1 - fgA) * bgB;

    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];

}

- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation {
    UIColor *newColor;
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
        newColor = [UIColor colorWithHue:h saturation:saturation brightness:b alpha:a];
    }
    return newColor;
}

@end
