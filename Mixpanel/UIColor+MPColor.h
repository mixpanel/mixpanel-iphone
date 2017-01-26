#import <UIKit/UIKit.h>

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0];

@interface UIColor (MPColor)

+ (UIColor *)mp_applicationPrimaryColor;
+ (UIColor *)mp_lightEffectColor;
+ (UIColor *)mp_extraLightEffectColor;
+ (UIColor *)mp_darkEffectColor;

- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation;

@end
