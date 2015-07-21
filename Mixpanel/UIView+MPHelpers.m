#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "MPCategoryHelpers.h"

// NB If you add any more fingerprint methods, increment this.
#define MP_FINGERPRINT_VERSION 1

@implementation UIView (MPHelpers)

- (int)mp_fingerprintVersion
{
    return MP_FINGERPRINT_VERSION;
}

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

// mp_targetActions
- (NSArray *)mp_targetActions
{
    NSMutableArray *targetActions = [NSMutableArray array];
    if ([self isKindOfClass:[UIControl class]]) {
        for (id target in [(UIControl *)(self) allTargets]) {
            UIControlEvents allEvents = UIControlEventAllTouchEvents | UIControlEventAllEditingEvents;
            for (NSUInteger e = 0; (allEvents >> e) > 0; e++) {
                UIControlEvents event = allEvents & (0x01 << e);
                if(event) {
                    NSArray *actions = [(UIControl *)(self) actionsForTarget:target forControlEvent:event];
                    NSArray *ignoreActions = @[@"preVerify:forEvent:", @"execute:forEvent:"];
                    for (NSString *action in actions) {
                        if ([ignoreActions indexOfObject:action] == NSNotFound)
                        {
                            [targetActions addObject:[NSString stringWithFormat:@"%lu/%@", (unsigned long)event, action]];
                        }
                    }
                }
            }
        }
    }
    return [targetActions copy];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
// Set by a userDefinedRuntimeAttr in the MPTagNibs.rb script
- (void)setMixpanelViewId:(id)object
{
    objc_setAssociatedObject(self, @selector(mixpanelViewId), [object copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)mp_viewId
{
    return objc_getAssociatedObject(self, @selector(mixpanelViewId));
}
#pragma clang diagnostic pop

- (NSString *)mp_controllerVariable
{
    NSString *result = nil;
    if ([self isKindOfClass:[UIControl class]]) {
        UIResponder *responder = [self nextResponder];
        while (responder && ![responder isKindOfClass:[UIViewController class]]) {
            responder = [responder nextResponder];
        }
        if (responder) {
            uint count;
            Ivar *ivars = class_copyIvarList([responder class], &count);
            for (uint i = 0; i < count; i++) {
                Ivar ivar = ivars[i];
                if (ivar_getTypeEncoding(ivar)[0] == '@' && object_getIvar(responder, ivar) == self) {
                    result = [NSString stringWithCString:ivar_getName(ivar) encoding:NSUTF8StringEncoding];
                    break;
                }
            }
            free(ivars);
        }
    }
    return result;
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
    UIImage *originalImage = nil;
    if ([self isKindOfClass:[UIButton class]]) {
        originalImage = [((UIButton *)self) imageForState:UIControlStateNormal];
    } else if ([NSStringFromClass([self class]) isEqual:@"UITabBarButton"] && [self.subviews count] > 0 && [self.subviews[0] respondsToSelector:NSSelectorFromString(@"image")]) {
        originalImage = [self.subviews[0] image];
    }
    
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
    return result;
}

- (NSString *)mp_text
{
    NSString *text = nil;
    SEL titleSelector = NSSelectorFromString(@"title");
    if ([self isKindOfClass:[UILabel class]]) {
        text = ((UILabel *)self).text;
    } else if ([self isKindOfClass:[UIButton class]]) {
        text = [((UIButton *)self) titleForState:UIControlStateNormal];
    } else if ([self respondsToSelector:titleSelector]) {
        IMP titleImp = [self methodForSelector:titleSelector];
        void *(*func)(id, SEL) = (void *(*)(id, SEL))titleImp;
        id title = (__bridge id)func(self, titleSelector);
        if ([title isKindOfClass:[NSString class]]) {
            text = title;
        }
    }
    return text;
}
        
static NSString* mp_encryptHelper(id input)
{
    NSString *SALT = @"1l0v3c4a8s4n018cl3d93kxled3kcle3j19384jdo2dk3";
    NSMutableString *encryptedStuff = nil;
    if ([input isKindOfClass:[NSString class]]) {
        NSData *data = [[input stringByAppendingString:SALT]  dataUsingEncoding:NSASCIIStringEncoding];
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
        encryptedStuff = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            [encryptedStuff appendFormat:@"%02x", digest[i]];
        }
    }
    return encryptedStuff;
}

#pragma mark - Aliases for compatibility
- (NSString *)mp_varA
{
    return mp_encryptHelper([self mp_viewId]);
}

- (NSString *)mp_varB
{
    return mp_encryptHelper([self mp_controllerVariable]);
}

- (NSString *)mp_varC
{
    return mp_encryptHelper([self mp_imageFingerprint]);
}

- (NSArray *)mp_varSetD
{
    NSArray *targetActions = [self mp_targetActions];
    NSMutableArray *encryptedActions = [NSMutableArray array];
    for (NSUInteger i = 0 ; i < [targetActions count]; i++) {
        [encryptedActions addObject:mp_encryptHelper(targetActions[i])];
    }
    return encryptedActions;
}

- (NSString *)mp_varE
{
    return mp_encryptHelper([self mp_text]);
}

@end
