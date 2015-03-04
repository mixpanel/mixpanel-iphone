#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

@interface UIView (MPHelpers)

- (UIImage *)mp_snapshotImage;
- (UIImage *)mp_snapshotForBlur;
- (int)mp_fingerprintVersion;

@end

