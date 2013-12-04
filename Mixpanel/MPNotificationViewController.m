//
//  MPNotificationViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "MPNotificationViewController.h"

#import "MPNotification.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

#import <QuartzCore/QuartzCore.h>

@interface MPAlphaMaskView : UIView {

@protected
    CAGradientLayer *_maskLayer;
}

@end

@interface MPButton : UIButton

@end

@interface MPBgRadialGradientView : UIView

@end

@interface MPNotificationViewController () {
    CGPoint _viewStart;
    BOOL _touching;
}

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet UILabel *titleView;
@property (nonatomic, strong) IBOutlet UILabel *bodyView;
@property (nonatomic, strong) IBOutlet UIButton *okayButton;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet MPAlphaMaskView *imageAlphaMaskView;
@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageWidth;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageHeight;
@property (nonatomic, strong) IBOutlet UIView *imageDragView;
@property (nonatomic, strong) IBOutlet UIView *bgMask;

@end

@implementation MPNotificationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.backgroundImageView.image = _backgroundImage;

    if (self.notification) {
        if (self.notification.image) {
            UIImage *image = [UIImage imageWithData:self.notification.image scale:2.0f];
            if (image) {
                self.imageWidth.constant = image.size.width;
                self.imageHeight.constant = image.size.height;
                self.imageView.image = image;
            } else {
                NSLog(@"image failed to load from data: %@", self.notification.image);
            }
        }

        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;

        if ([self.notification.cta length] > 0) {
            [self.okayButton setTitle:self.notification.cta forState:UIControlStateNormal];
            [self.okayButton sizeToFit];
        }
    }

    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.imageView.layer.shadowOpacity = 1.0f;
    self.imageView.layer.shadowRadius = 5.0f;
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;

    [self.okayButton addTarget:self action:@selector(pressedOkay) forControlEvents:UIControlEventTouchUpInside];
    [self.closeButton addTarget:self action:@selector(pressedClose) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.imageDragView addGestureRecognizer:gesture];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self.okayButton sizeToFit];
    [self.imageAlphaMaskView sizeToFit];

}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated
{
    [super beginAppearanceTransition:isAppearing animated:animated];

    if (isAppearing) {
        self.bgMask.alpha = 0.0f;
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

    NSTimeInterval duration = 0.20f;

    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 10.0f);
    transform = CGAffineTransformScale(transform, 0.9f, 0.9f);
    self.imageView.transform = transform;
    self.titleView.transform = transform;
    self.bodyView.transform = transform;
    self.okayButton.transform = transform;

    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.titleView.transform = CGAffineTransformIdentity;
        self.titleView.alpha = 1.0f;
        self.bodyView.transform = CGAffineTransformIdentity;
        self.bodyView.alpha = 1.0f;
        self.okayButton.transform = CGAffineTransformIdentity;
        self.okayButton.alpha = 1.0f;
        self.imageView.transform = CGAffineTransformIdentity;
        self.imageView.alpha = 1.0f;
        self.bgMask.alpha = 1.0f;
    } completion:nil];

    [UIView animateWithDuration:duration delay:0.15f options:UIViewAnimationOptionCurveEaseOut animations:^{
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

- (void)didPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.numberOfTouches == 1) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            _viewStart = self.imageView.layer.position;
            _touching = YES;
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [gesture translationInView:self.view];
            self.imageView.layer.position = CGPointMake(0.3f * (translation.x) + _viewStart.x, 0.3f * (translation.y) + _viewStart.y);
        }
    }

    if (_touching && (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled)) {
        _touching = NO;
        CGPoint viewEnd = self.imageView.layer.position;
        CGPoint viewDistance = CGPointMake(viewEnd.x - _viewStart.x, viewEnd.y - _viewStart.y);
        CGFloat distance = sqrtf(viewDistance.x * viewDistance.x + viewDistance.y * viewDistance.y);
        [UIView animateWithDuration:(distance / 500.0f) delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.imageView.layer.position = _viewStart;
        } completion:nil];
    }
}

@end

@implementation MPAlphaMaskView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super initWithCoder:aDecoder]) {
        _maskLayer = [CAGradientLayer layer];

        _maskLayer.colors = @[(id)[[UIColor colorWithWhite:1.0 alpha:1.0] CGColor],
                              (id)[[UIColor colorWithWhite:1.0 alpha:0.0] CGColor]];
        [self.layer setMask:_maskLayer];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_maskLayer setFrame:self.bounds];
    _maskLayer.locations = @[[NSNumber numberWithFloat:1.0f - (60.0f / self.bounds.size.height)],
                             [NSNumber numberWithFloat:1.0f]];
}

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
        self.layer.borderColor = [UIColor grayColor].CGColor;
    } else {
        self.layer.borderColor = [UIColor whiteColor].CGColor;
    }

    [super setHighlighted:highlighted];
}

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
    CGFloat locs[] = {0.0f, 0.1f, 0.75, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, comps, locs, 4);

    CGContextAddEllipseInRect(ctx, circleFrame);
    CGContextClip(ctx);

    CGContextDrawRadialGradient(ctx, gradient, center, 0.0f, center, circleSize.width / 2.0f, kCGGradientDrawsAfterEndLocation);

    CGContextRestoreGState(ctx);

    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);
}

@end
