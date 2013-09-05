#import <QuartzCore/QuartzCore.h>

#import "UIView+MPSnapshotImage.h"

@implementation UIView (MPSnapshotImage)

// taken from https://github.com/romaonthego/RESideMenu/blob/master/RESideMenu/UIView%2BImageSnapshot.m
- (UIImage *)mp_snapshotImage
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    } else {
        UIGraphicsBeginImageContext(self.bounds.size);
    }
    if ([self respondsToSelector:@selector(drawViewHierarchyInRect:)]) {
        NSInvocation* invoc = [NSInvocation invocationWithMethodSignature:
                               [self methodSignatureForSelector:
                                @selector(drawViewHierarchyInRect:)]];
        [invoc setTarget:self];
        [invoc setSelector:@selector(drawViewHierarchyInRect:)];
        CGRect arg2 = self.bounds;
        [invoc setArgument:&arg2 atIndex:2];
        [invoc invoke];
    } else {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
