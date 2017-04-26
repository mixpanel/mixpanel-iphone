#import "UIImage+MPAverageColor.h"

@implementation UIImage (MPAverageColor)

- (UIColor *)mp_averageColor
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 0.f);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
    [self drawInRect:CGRectMake(0, 0, 1, 1) blendMode:kCGBlendModeCopy alpha:1];
    
    uint8_t *data = CGBitmapContextGetData(ctx);
    UIColor *color = [UIColor colorWithRed:data[2] / 255.0f
                                     green:data[1] / 255.0f
                                      blue:data[0] / 255.0f
                                     alpha:1];
    UIGraphicsEndImageContext();
    
    return color;
}

- (UIColor *)mp_importantColor {
    static const size_t kImageStartRow = 40;
    static const size_t kNumberOfRows = 124;
    static const size_t kNumberOfHexColors = 262144;
    
    const size_t kImageWidth = CGImageGetWidth(self.CGImage);
    const size_t kImageHeight = CGImageGetHeight(self.CGImage);
    
    const size_t kBytesPerPixel = CGImageGetBitsPerPixel(self.CGImage) / 8;
    const size_t kBytesPerRow = CGImageGetBytesPerRow(self.CGImage);
    
    // Don't calculate
    if (kImageHeight < kImageStartRow + kNumberOfRows) {
        return [self mp_averageColor];
    }
    
    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage));
    const uint8_t *imageDataBuffer = CFDataGetBytePtr(imageData);
    
    char colorIndices[kNumberOfHexColors];
    memset(colorIndices, 0, sizeof(char) * kNumberOfHexColors);
    
    for (size_t rowIndex = kImageStartRow; rowIndex < kImageStartRow + kNumberOfRows; rowIndex++) {
        const uint8_t *row = imageDataBuffer + kBytesPerRow * rowIndex;
        for (size_t column = 0; column < kImageWidth; column++) {
            const uint8_t red = row[0];
            const uint8_t green = row[1];
            const uint8_t blue = row[2];
            
            const int hexColor = (red >> 2) + ((green >> 2) << 6) + ((blue >> 2) << 12);
            BOOL validHexColor = (0 < hexColor && hexColor < (int)kNumberOfHexColors - 1);
            if (validHexColor) {
                
                BOOL notTooBright = (red + green + blue < 255 + 255 + 200);
                if (notTooBright) {
                    
                    BOOL notGrayScale = (red != blue && blue != green && green != red);
                    if (notGrayScale) {
                        colorIndices[hexColor]++;
                    }
                }
            }
            row += kBytesPerPixel;
        }
    }
    
    NSUInteger index = 0;
    char max = 0;
    for (NSUInteger i = 0; i < kNumberOfHexColors; i++) {
        if (colorIndices[i] > max) {
            max = colorIndices[i];
            index = i;
        }
    }
    
    return [UIColor colorWithRed:(((index & 63) << 2) + 3) / 255.0f
                           green:(((index >> 4) & 252) + 3) / 255.0f
                            blue:(((index >> 10) & 252) + 3) / 255.0f
                           alpha:1];
}

@end
