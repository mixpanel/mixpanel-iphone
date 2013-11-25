//
//  MPNotificationSmallViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "MPNotificationSmallViewController.h"

#import "MPNotification.h"

#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"
#import "UIColor+MPColor.h"

#define kMPNotifHeight 65.0f

@interface CircleLayer : CALayer
@end

@implementation CircleLayer

-(void)drawInContext:(CGContextRef)ctx
{
    CGFloat edge = 1.0f; //the distance from the edge so we don't get clipped.
    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGMutablePathRef thePath = CGPathCreateMutable();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGPathAddArc(thePath, NULL, self.frame.size.width / 2.0f, self.frame.size.height / 2.0f, MIN(self.frame.size.width, self.frame.size.height) / 2.0f - (2 * edge), (float)-M_PI, (float)M_PI, YES);

    CGContextBeginPath(ctx);
    CGContextAddPath(ctx, thePath);

    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);

    CFRelease(thePath);
}

@end

@interface MPNotificationSmallViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CALayer *circleLayer;
@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UILabel *bodyLabel;

@end

@implementation MPNotificationSmallViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _canPan = YES;
    self.view.clipsToBounds = YES;

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _imageView.layer.masksToBounds = YES;

    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _bodyLabel.textColor = [UIColor whiteColor];
    _bodyLabel.font = [UIFont systemFontOfSize:14.0f];
    _bodyLabel.numberOfLines = 2;

    UIImage *bgImage = [self.parentViewController.view mp_snapshotImage];
    self.bgImageView = [[UIImageView alloc] initWithFrame:CGRectZero];

    UIColor *blurColor = [UIColor applicationPrimaryColor];
    if (!blurColor) {
        blurColor = [bgImage mp_importantColor];
    }
    blurColor = [blurColor colorWithAlphaComponent:0.7f];

    _bgImageView.image = [bgImage mp_applyBlurWithRadius:5.0f tintColor:blurColor saturationDeltaFactor:1.8f maskImage:nil];
    _bgImageView.opaque = YES;

    if (self.notification != nil) {
        if (self.notification.image != nil) {
            _imageView.image = [UIImage imageWithData:self.notification.image scale:2.0f];
            _imageView.hidden = NO;
        } else {
            _imageView.hidden = YES;
        }

        if (self.notification.body != nil) {
            _bodyLabel.text = self.notification.body;
            _bodyLabel.hidden = NO;
        } else {
            _bodyLabel.hidden = YES;
        }
    }

    self.circleLayer = [CircleLayer layer];
    _circleLayer.contentsScale = [UIScreen mainScreen].scale;
    [_circleLayer setNeedsDisplay];

    [self.view addSubview:_bgImageView];
    [self.view addSubview:_imageView];
    [self.view addSubview:_bodyLabel];
    [self.view.layer addSublayer:_circleLayer];
	
    self.view.backgroundColor = [UIColor colorWithRed:24.0f / 255.0f green:24.0f / 255.0f blue:31.0f / 255.0f alpha:0.9f];
    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    gesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:gesture];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIView *parentView = self.parentViewController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight * 3.0f);

    // Position images
    CGSize parentSize = parentView.frame.size;
    self.bgImageView.frame = CGRectMake(0.0f, kMPNotifHeight - parentSize.height, parentSize.width, parentSize.height);
    CGRect imvf = CGRectMake(20.0f, 20.0f, kMPNotifHeight - 40.0f, kMPNotifHeight - 40.0f);
    self.imageView.frame = imvf;

    // Position circle around image
    CGFloat circlePadding = 7.0f;
    self.circleLayer.frame = CGRectMake(imvf.origin.x - circlePadding, imvf.origin.y - circlePadding, imvf.size.width + (circlePadding * 2.0f), imvf.size.height + (circlePadding * 2.0f));

    // Position body label
    CGFloat offsetX = self.imageView.frame.size.width + self.imageView.frame.origin.x + 20.5f;
    self.bodyLabel.frame = CGRectMake(offsetX, 12.5f, self.view.frame.size.width - offsetX - 12.5f, 0.0f);
    [self.bodyLabel sizeToFit];
}

- (void)showWithAnimation
{
    _canPan = NO;

    UIView *parentView = self.parentViewController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height, parentView.frame.size.width, kMPNotifHeight * 3.0f);

    CGPoint bgPosition = self.bgImageView.layer.position;
    self.bgImageView.frame = CGRectMake(0.0f, 0.0f - parentView.frame.size.height, self.view.frame.size.width, parentView.frame.size.height);

    _position = self.view.layer.position;

    [UIView animateWithDuration:0.5f animations:^{
        self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight * 3.0f);
        self.bgImageView.layer.position = bgPosition;
    } completion:^(BOOL finished) {
        _position = self.view.layer.position;
        _canPan = YES;
    }];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    if (self.parentViewController == nil) {
        return;
    }

    _canPan = NO;

    CGFloat duration;

    if (animated) {
        duration = 0.5f;
    } else {
        duration = 0.0f;
    }

    [UIView animateWithDuration:duration animations:^{
        UIView *parentView = self.parentViewController.view;
        self.view.frame = CGRectMake(0.0f, parentView.frame.size.height, parentView.frame.size.width, kMPNotifHeight * 3.0f);
        self.bgImageView.frame = CGRectMake(0.0f, 0.0f - parentView.frame.size.height, self.view.frame.size.width, parentView.frame.size.height);
    } completion:^(BOOL finished) {
        if (completion) {
            completion();
        }
    }];
}

- (void)didTap:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (self.delegate != nil) {
            [self.delegate notificationSmallControllerWasDismissed:self status:YES];
        }
    }
}

- (void)didPan:(UIPanGestureRecognizer *)gesture
{
    if (_canPan) {
        if (gesture.state == UIGestureRecognizerStateBegan && gesture.numberOfTouches == 1) {
            _panStartPoint = [gesture locationInView:self.parentViewController.view];
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint position = [gesture locationInView:self.parentViewController.view];
            CGFloat diffY = position.y - _panStartPoint.y;

            if (diffY > 0) {
                position.y = _position.y + diffY * 2.0f;
            } else {
                position.y = _position.y + diffY * 0.1f;
            }

            self.view.layer.position = CGPointMake(self.view.layer.position.x, position.y);
            CGRect bgFrame = self.bgImageView.frame;
            bgFrame.origin.y = -self.view.frame.origin.y;
            self.bgImageView.frame = bgFrame;
        } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
            if (self.view.layer.position.y > _position.y + kMPNotifHeight / 2.0f && self.delegate != nil) {
                [self.delegate notificationSmallControllerWasDismissed:self status:NO];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = _position;
                    CGRect bgFrame = self.bgImageView.frame;
                    bgFrame.origin.y = -self.view.frame.origin.y;
                    self.bgImageView.frame = bgFrame;
                }];
            }
        }
    }
}


- (void)dealloc
{
    self.delegate = nil;
}


@end

