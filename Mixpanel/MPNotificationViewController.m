//
//  MPNotificationViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotificationViewController.h"

#import "MPNotification.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

#import <QuartzCore/QuartzCore.h>

@interface MPNotificationViewController ()

@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UILabel *titleView;
@property (nonatomic, retain) IBOutlet UILabel *bodyView;
@property (nonatomic, retain) IBOutlet UIButton *okayButton;
@property (nonatomic, retain) IBOutlet UIButton *closeButton;
@property (nonatomic, retain) IBOutlet UIView *bodyBg;
@property (nonatomic, retain) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *imageWidth;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *imageHeight;

@end

@implementation MPNotificationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.backgroundImageView.image = _backgroundImage;
    
    if (self.notification) {
        if ([self.notification.imageUrls count] > 0) {
            NSData *imageData = self.notification.images[0];
            UIImage *image = [UIImage imageWithData:imageData scale:2.0f];
            if (image) {
                self.imageWidth.constant = image.size.width;
                self.imageHeight.constant = image.size.height;
                self.imageView.image = image;
            } else {
                NSLog(@"image failed to load from data: %@", imageData);
            }
        }
        
        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;
        
        if ([self.notification.cta length] > 0) {
            [self.okayButton setTitle:self.notification.cta forState:UIControlStateNormal];
            [self.okayButton sizeToFit];
        }
    }
    
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1 alpha:1].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor];
    // add 44 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 105.0f / self.bodyBg.bounds.size.height;
    fadeLayer.locations = @[@0, @(offset), @1];
    fadeLayer.bounds = self.bodyBg.bounds;
    fadeLayer.anchorPoint = CGPointZero;
    self.bodyBg.layer.mask = fadeLayer;
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.imageView.layer.shadowOpacity = 1.0f;
    self.imageView.layer.shadowRadius = 5.0f;
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    
    [self.okayButton addTarget:self action:@selector(pressedOkay) forControlEvents:UIControlEventTouchUpInside];
    [self.closeButton addTarget:self action:@selector(pressedClose) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.okayButton sizeToFit];
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1 alpha:1].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor];
    // add 44 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 105.0f / self.bodyBg.bounds.size.height;
    fadeLayer.locations = @[@0, @(offset), @1];
    fadeLayer.bounds = self.bodyBg.bounds;
    fadeLayer.anchorPoint = CGPointZero;
    self.bodyBg.layer.mask = fadeLayer;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}


- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated
{
    [super beginAppearanceTransition:isAppearing animated:animated];
    
    if (isAppearing && animated) {
        self.imageView.alpha = 0.0f;
        self.titleView.alpha = 0.0f;
        self.bodyView.alpha = 0.0f;
        self.okayButton.alpha = 0.0f;
        self.closeButton.alpha = 0.0f;
    }
}

- (void)endAppearanceTransition
{
    [super endAppearanceTransition];
    NSTimeInterval duration = 0.2f;
    
    self.bodyBg.alpha = 1.0f;
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 10.0f);
    transform = CGAffineTransformScale(transform, 0.9f, 0.9f);
    self.imageView.transform = transform;
    self.titleView.transform = transform;
    self.bodyView.transform = transform;
    self.okayButton.transform = transform;

    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.titleView.transform = CGAffineTransformIdentity;
        self.titleView.alpha = 1.0f;
        self.bodyView.transform = CGAffineTransformIdentity;
        self.bodyView.alpha = 1.0f;
        self.okayButton.transform = CGAffineTransformIdentity;
        self.okayButton.alpha = 1.0f;
    } completion:nil];

    [UIView animateWithDuration:duration delay:0.15f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.imageView.transform = CGAffineTransformIdentity;
        self.imageView.alpha = 1.0f;
    } completion:nil];

    [UIView animateWithDuration:duration delay:0.3f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.closeButton.transform = CGAffineTransformIdentity;
        self.closeButton.alpha = 1.0f;
    } completion:nil];
}

- (void)pressedOkay
{
    if (self.delegate) {
        [self.delegate notificationControllerWasDismissed:self status:YES];
    }
}

- (void)pressedClose
{
    if (self.delegate) {
        [self.delegate notificationControllerWasDismissed:self status:NO];
    }
}

@end

@interface MPRadialGradientView : UIView

@end

@implementation MPRadialGradientView

- (void)drawRect:(CGRect)rect
{
    CGSize size = self.bounds.size;
    CGPoint center = self.bounds.origin;
    center.x += size.width;
    center.y += size.height;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[] = {43.0f / 255.0f, 43.0f / 255.0f, 57.0f / 255.0f, 1.0f, 43.0f / 255.0f, 43.0f / 255.0f, 57.0f / 255.0f, 0.0f};
    CGFloat locs[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, comps, locs, 2);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, center.x, center.y);
    CGPathAddLineToPoint(path, NULL, center.x - size.width, center.y);
    CGPathAddArcToPoint(path, NULL, center.x - size.width, center.y - size.width, center.x, center.y - size.width, size.width);
    CGPathAddLineToPoint(path, NULL, center.x, center.y);
    
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    
    CGContextDrawRadialGradient(ctx, gradient, center, 1.0f, center, size.width, 0);
    
    CGContextRestoreGState(ctx);
}

@end

@interface MPBgRadialGradientView : UIView

@end

@implementation MPBgRadialGradientView

- (void)drawRect:(CGRect)rect
{
    CGPoint center = CGPointMake(160.0f, 200.0f);
    CGSize circleSize = CGSizeMake(center.y * 2.0f, center.y * 2.0f);
    CGRect circleFrame = CGRectMake(center.x - center.y, 0.0f, circleSize.width, circleSize.height);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    CGColorRef colorRef = [UIColor colorWithRed:24.0f / 255.0f green:24.0f / 255.0f blue:31.0f / 255.0f alpha:0.94f].CGColor;
    CGContextSetFillColorWithColor(ctx, colorRef);
    CGContextFillRect(ctx, self.bounds);
    
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[] = {24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.7f,
        24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.7f,
        24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.9f,
        24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.94f};
    CGFloat locs[] = {0.0f, 0.5f, 0.75, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, comps, locs, 4);
    
    CGContextAddEllipseInRect(ctx, circleFrame);
    CGContextClip(ctx);
    
    CGContextDrawRadialGradient(ctx, gradient, center, 1.0f, center, circleSize.width / 2.0f, kCGGradientDrawsAfterEndLocation);
    
    CGContextRestoreGState(ctx);
}

@end

@interface MPButton : UIButton

@end

@implementation MPButton

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.layer.backgroundColor = [UIColor colorWithRed:43.0f/255.0f green:43.0f/255.0f blue:52.0f/255.0f alpha:1.0f].CGColor;
        self.layer.cornerRadius = 17.0f;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2.0f;
    }
    
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        self.layer.borderColor = [UIColor colorWithRed:26.0f/255.0f green:26.0f/255.0f blue:35.0f/255.0f alpha:1.0f].CGColor;
    } else {
        self.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    
    [super setHighlighted:highlighted];
}

@end
