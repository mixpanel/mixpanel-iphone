#import <UIKit/UIKit.h>

@interface UIColor (AloomaColor)

+ (UIColor *)mp_applicationPrimaryColor;
+ (UIColor *)mp_lightEffectColor;
+ (UIColor *)mp_extraLightEffectColor;
+ (UIColor *)mp_darkEffectColor;

- (UIColor *)colorWithSaturationComponent:(CGFloat) saturation;

@end
