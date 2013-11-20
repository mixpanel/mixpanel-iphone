#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "UIImage+MPAverageColor.h"

@implementation UIImage (MPAverageColor)

- (UIColor *)mp_averageColor
{
	CGSize size = {1, 1};
	UIGraphicsBeginImageContext(size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
	[self drawInRect:(CGRect){.size = size} blendMode:kCGBlendModeCopy alpha:1];
	uint8_t *data = CGBitmapContextGetData(ctx);
	UIColor *color = [UIColor colorWithRed:data[2] / 255.0f
									 green:data[1] / 255.0f
									  blue:data[0] / 255.0f
									 alpha:1];
	UIGraphicsEndImageContext();
	return color;
}

@end
