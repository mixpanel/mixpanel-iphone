#import <UIKit/UIKit.h>

@interface UIColor (MPColor)

+ (UIColor *)mp_applicationPrimaryColor;
+ (UIColor *)mp_lightEffectColor;
+ (UIColor *)mp_extraLightEffectColor;
+ (UIColor *)mp_darkEffectColor;

+ (UIColor *)mp_colorFromRGB:(NSUInteger)rgbValue;
- (UIColor *)mp_colorAddColor:(UIColor *)overlay;
- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation;

@end
