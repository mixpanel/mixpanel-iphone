//
//  MPNotificationSmallViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotificationSmallViewController.h"

#import "MPNotification.h"

#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

#define kMPNotifHeight 65.0f

@interface MPNotificationSmallViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
}

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) CALayer *circleLayer;
@property (nonatomic, retain) UIImageView *bgImage;
@property (nonatomic, retain) UILabel *bodyLabel;

@end

@implementation MPNotificationSmallViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _canPan = YES;
    self.view.clipsToBounds = YES;

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.imageView.layer.masksToBounds = YES;

    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bodyLabel.textColor = [UIColor whiteColor];
    self.bodyLabel.font = [UIFont systemFontOfSize:14.0f];
    self.bodyLabel.numberOfLines = 2;

    UIImage *bgImage = [self.parentController.view mp_snapshotImage];

    self.bgImage = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.bgImage.image = [bgImage mp_applyDarkEffect];
    self.bgImage.opaque = YES;

    /*
    CGFloat hue;
    CGFloat brightness;
    CGFloat saturation;
    CGFloat alpha;
    if ([avgColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        avgColor = [UIColor colorWithHue:hue saturation:0.8f brightness:brightness alpha:alpha];
    }
     */

    if (self.notification != nil) {
        if (self.notification.image != nil) {
            self.imageView.image = [UIImage imageWithData:self.notification.image scale:2.0f];
            self.imageView.hidden = NO;
        } else {
            self.imageView.hidden = YES;
        }

        if (self.notification.body != nil) {
            self.bodyLabel.text = self.notification.body;
            self.bodyLabel.hidden = NO;
        } else {
            self.bodyLabel.hidden = YES;
        }
    }

    [self.view addSubview:self.bgImage];
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.bodyLabel];
	
    self.view.backgroundColor = [UIColor colorWithRed:24.0f / 255.0f green:24.0f / 255.0f blue:31.0f / 255.0f alpha:0.9f];
    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    gesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:gesture];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:pan];

    self.circleLayer = [CALayer layer];
    self.circleLayer.delegate = self;
    self.circleLayer.contentsScale = [UIScreen mainScreen].scale;

    [self.view.layer addSublayer:self.circleLayer];
    [self.circleLayer setNeedsDisplay];
}

- (void)dealloc
{
    [super dealloc];

    self.parentController = nil;
    self.notification = nil;
    self.imageView = nil;
    self.circleLayer = nil;
    self.bgImage = nil;
    self.bodyLabel = nil;
    self.delegate = nil;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIView *parentView = self.parentController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight * 3.0f);

    // Position images
    CGSize parentSize = self.parentController.view.frame.size;
    self.bgImage.frame = CGRectMake(0.0f, kMPNotifHeight - parentSize.height, parentSize.width, parentSize.height);
    CGRect imvf = CGRectMake(12.5f, 12.5f, kMPNotifHeight - 25.0f, kMPNotifHeight - 25.0f);
    self.imageView.frame = imvf;

    // Position circle around image
    self.circleLayer.frame = CGRectMake(imvf.origin.x - 4.0, imvf.origin.y - 4.0, imvf.size.width + 8.0, imvf.size.height + 8.0);

    // Position body label
    CGFloat offsetX = self.imageView.frame.size.width + self.imageView.frame.origin.x + 12.5f;
    self.bodyLabel.frame = CGRectMake(offsetX, 12.5f, self.view.frame.size.width - offsetX - 12.5f, 0.0f);
    [self.bodyLabel sizeToFit];
}

- (void)show
{
    _canPan = NO;

    [self.parentController addChildViewController:self];
    [self.parentController.view addSubview:self.view];
    [self didMoveToParentViewController:self.parentController];

    UIView *parentView = self.parentController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height, parentView.frame.size.width, kMPNotifHeight * 3.0f);

    CGPoint bgPosition = self.bgImage.layer.position;
    self.bgImage.frame = CGRectMake(0.0f, 0.0f - parentView.frame.size.height, self.view.frame.size.width, parentView.frame.size.height);

    [UIView animateWithDuration:0.5f animations:^{
        self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight * 3.0f);
        self.bgImage.layer.position = bgPosition;
    } completion:^(BOOL finished) {
        _position = self.view.layer.position;
        _canPan = YES;
    }];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    if (self.parentController == nil) {
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
        UIView *parentView = self.parentController.view;
        self.view.frame = CGRectMake(0.0f, parentView.frame.size.height, parentView.frame.size.width, kMPNotifHeight * 3.0f);
        self.bgImage.frame = CGRectMake(0.0f, 0.0f - parentView.frame.size.height, self.view.frame.size.width, parentView.frame.size.height);
    } completion:^(BOOL finished) {
        [self willMoveToParentViewController:nil];
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
        self.parentController = nil;

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
            _panStartPoint = [gesture locationInView:self.parentController.view];
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint position = [gesture locationInView:self.parentController.view];
            CGFloat diffY = position.y - _panStartPoint.y;

            if (diffY > 0) {
                position.y = _position.y + diffY * 2.0f;
            } else {
                position.y = _position.y + diffY * 0.1f;
            }

            self.view.layer.position = CGPointMake(self.view.layer.position.x, position.y);
            CGRect bgFrame = self.bgImage.frame;
            bgFrame.origin.y = -self.view.frame.origin.y;
            self.bgImage.frame = bgFrame;
        } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
            if (self.view.layer.position.y > _position.y + kMPNotifHeight / 2.0f && self.delegate != nil) {
                [self.delegate notificationSmallControllerWasDismissed:self status:NO];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = _position;
                    CGRect bgFrame = self.bgImage.frame;
                    bgFrame.origin.y = -self.view.frame.origin.y;
                    self.bgImage.frame = bgFrame;
                }];
            }
        }
    }
}

#pragma mark - CALayer delegate

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    CGFloat padding = 1.0f;
    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGMutablePathRef thePath = CGPathCreateMutable();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGPathAddArc(thePath, NULL, layer.frame.size.width / 2.0f, layer.frame.size.height / 2.0f, MIN(layer.frame.size.width, layer.frame.size.height) / 2.0f - (2 * padding), (float)-M_PI, (float)M_PI, YES);

    CGContextBeginPath(ctx);
    CGContextAddPath(ctx, thePath);

    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);

    // Release the path
    CFRelease(thePath);
}

@end

