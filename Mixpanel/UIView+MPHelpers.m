#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import <QuartzCore/QuartzCore.h>
#import "NSData+MPBase64.h"
#import "UIView+MPHelpers.h"

@implementation UIView (MPHelpers)

- (UIImage *)mp_snapshotImage
{
    CGFloat offsetHeight = 0.0f;

    //Avoid the status bar on phones running iOS < 7
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending &&
        ![UIApplication sharedApplication].statusBarHidden) {
        offsetHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    CGSize size = self.layer.bounds.size;
    size.height -= offsetHeight;
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0f, -offsetHeight);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([self respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [self drawViewHierarchyInRect:CGRectMake(0.0f, 0.0f, size.width, size.height) afterScreenUpdates:YES];
    } else {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
#else
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
#endif

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)mp_snapshotForBlur
{
    UIImage *image = [self mp_snapshotImage];
    // hack, helps with colors when blurring
    NSData *imageData = UIImageJPEGRepresentation(image, 1); // convert to jpeg
    return [UIImage imageWithData:imageData];
}

- (NSArray *)mp_targetActions
{
    NSMutableArray *targetActions = [NSMutableArray array];
    if ([self isKindOfClass:[UIControl class]]) {
        for (id target in [(UIControl *)(self) allTargets]) {
            UIControlEvents allEvents = UIControlEventAllTouchEvents | UIControlEventAllEditingEvents;
            for(NSUInteger e = 0; (allEvents >> e) > 0; e++) {
                UIControlEvents event = allEvents & (0x01 << e);
                if(event) {
                    NSArray *actions = [(UIControl *)(self) actionsForTarget:target forControlEvent:event];
                    for (NSString *action in actions) {
                        [targetActions addObject:[NSString stringWithFormat:@"%lu/%@", event, action]];
                    }
                }
            }
        }
    }
    return [targetActions copy];
}

- (NSArray *)mp_constraints
{
    NSMutableArray *constraints = [NSMutableArray array];
    for (NSLayoutConstraint *c in self.constraints) {
        [constraints addObject:[NSString stringWithFormat:@"%f/%ld/%ld/%ld/%f/%f", c.priority, c.firstAttribute, c.secondAttribute, c.relation, c.multiplier, c.constant]];
    }
    return constraints;
}

- (NSString *)mp_position
{
    return [NSString stringWithFormat:@"%d,%d", (int)self.frame.origin.x, (int)self.frame.origin.y];
}

- (NSString *)mp_size
{
    return [NSString stringWithFormat:@"%d,%d", (int)self.frame.size.width, (int)self.frame.size.height];
}

/*
 Creates a short string which is a fingerprint of a UIButton's image property.
 It does this by downsampling the image to 8x8 and then downsampling the resulting
 32bit pixel data to 8 bit. This should allow us to select images that are identical or
 almost identical in appearance without having to compare the whole image.

 Returns a base64 encoded string representing an 8x8 bitmap of 8 bit rgba data
 (2 bits per component).
 */
- (NSString *)mp_imageFingerprint
{
    NSString *result = nil;
    if ([self isKindOfClass:[UIButton class]]) {
        UIImage *originalImage = [((UIButton *)self) imageForState:UIControlStateNormal];
        if (originalImage) {
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            uint32_t data32[64];
            uint8_t data4[32];
            CGContextRef context = CGBitmapContextCreate(data32, 8, 8, 8, 8*4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
            CGContextSetAllowsAntialiasing(context, NO);
            CGContextClearRect(context, CGRectMake(0, 0, 8, 8));
            CGContextSetInterpolationQuality(context, kCGInterpolationNone);
            CGContextDrawImage(context, CGRectMake(0,0,8,8), [originalImage CGImage]);
            CGColorSpaceRelease(space);
            CGContextRelease(context);
            for(int i = 0; i < 32; i++) {
                int j = 2*i;
                int k = 2*i + 1;
                data4[i] = (((data32[j] & 0x80000000) >> 24) | ((data32[j] & 0x800000) >> 17) | ((data32[j] & 0x8000) >> 10) | ((data32[j] & 0x80) >> 3) |
                            ((data32[k] & 0x80000000) >> 28) | ((data32[k] & 0x800000) >> 21) | ((data32[k] & 0x8000) >> 14) | ((data32[k] & 0x80) >> 7));
            }
            result = [[NSData dataWithBytes:data4 length:32] base64EncodedStringWithOptions:0];
        }
    }
    return result;
}

@end
