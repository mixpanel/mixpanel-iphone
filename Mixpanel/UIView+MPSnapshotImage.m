#import <QuartzCore/QuartzCore.h>

#import "UIView+MPSnapshotImage.h"

@implementation UIView (MPSnapshotImage)

- (UIImage *)mp_snapshotImage
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    if ([self respondsToSelector:@selector(drawViewHierarchyInRect:)]) {
        [self drawViewHierarchyInRect:self.bounds];
    } else {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
