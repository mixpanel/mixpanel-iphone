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

@interface CircleLayer : CALayer {
    @public
    CGFloat circlePadding;
}

@end

@implementation CircleLayer

+ (id)layer {
    CircleLayer *cl = (CircleLayer *)[super layer];
    cl->circlePadding = 2.5f;
    return cl;
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGFloat edge = 1.5f; //the distance from the edge so we don't get clipped.
    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGMutablePathRef thePath = CGPathCreateMutable();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGPathAddArc(thePath, NULL, self.frame.size.width / 2.0f, self.frame.size.height / 2.0f, MIN(self.frame.size.width, self.frame.size.height) / 2.0f - (2 * edge), (float)-M_PI, (float)M_PI, YES);

    CGContextBeginPath(ctx);
    CGContextAddPath(ctx, thePath);

    CGContextSetLineWidth(ctx, 1.5f);
    CGContextStrokePath(ctx);

    CFRelease(thePath);
}

@end

@interface ElasticEaseOutAnimation : CAKeyframeAnimation {}

#define kFPS 60

@end

@implementation ElasticEaseOutAnimation

- (id)initWithStartValue:(NSValue *)start endValue:(NSValue *)end andDuration:(double)duration
{
    if ((self = [super init]))
    {
        self.duration = duration;
        self.values = [self generateValuesFrom:start to:end];
    }
    return self;
}

- (NSArray *)generateValuesFrom:(NSValue *)startValue to:(NSValue *)endValue
{
    NSUInteger steps = (NSUInteger)ceil(kFPS * self.duration) + 2;
	NSMutableArray *valueArray = [NSMutableArray arrayWithCapacity:steps];
    const double increment = 1.0 / (double)(steps - 1);
    double t = 0.0;
    CGRect start = [startValue CGRectValue];
    CGRect end = [endValue CGRectValue];
    CGRect range = CGRectMake(end.origin.x - start.origin.x, end.origin.y - start.origin.y, end.size.width - start.size.width, end.size.height - start.size.height);

    NSUInteger i;
    for (i = 0; i < steps; i++) {
        float v = (float) -(pow(M_E, -8*t) * cos(12*t)) + 1; // Cosine wave with exponential decay

        CGRect value = CGRectMake(start.origin.x + v * range.origin.x,
                           start.origin.y + v * range.origin.y,
                           start.size.width + v * range.size.width,
                           start.size.height + v *range.size.height);

        [valueArray addObject:[NSValue valueWithCGRect:value]];
        t += increment;
    }

    return [NSArray arrayWithArray:valueArray];
}

@end

@interface MPNotificationSmallViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CircleLayer *circleLayer;
@property (nonatomic, strong) UIToolbar *uiToolbarView;
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
    _bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _bodyLabel.numberOfLines = 0;

    UIColor *blurColor = [UIColor applicationPrimaryColor];
    if (!blurColor) {
        blurColor = [UIColor darkEffectColor];
    }
    blurColor = [blurColor colorWithAlphaComponent:0.7f];
    
    self.uiToolbarView = [[UIToolbar alloc] init];
    [_uiToolbarView setBarTintColor:[blurColor colorWithAlphaComponent:0.8f]];
    _uiToolbarView.translucent = YES;

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

    [self.view addSubview:_uiToolbarView];
    [self.view addSubview:_imageView];
    [self.view addSubview:_bodyLabel];
    [self.view.layer addSublayer:_circleLayer];

    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    gesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:gesture];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)viewWillLayoutSubviews
{
    UIView *parentView = self.view.superview;

    double angle = [self angleForInterfaceOrientation:[self interfaceOrientation]];
    CGRect parentFrame = CGRectApplyAffineTransform(parentView.frame, CGAffineTransformMakeRotation((float)angle));

    self.view.frame = CGRectMake(0.0f, parentFrame.size.height - kMPNotifHeight, parentFrame.size.width, kMPNotifHeight * 3.0f);

    // Position images
    _uiToolbarView.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    _imageView.layer.position = CGPointMake(kMPNotifHeight / 2.0f, kMPNotifHeight / 2.0f);

    // Position circle around image
    _circleLayer.position = self.imageView.layer.position;
    [_circleLayer setNeedsDisplay];

    // Position body label
    CGSize constraintSize = CGSizeMake(self.view.frame.size.width - kMPNotifHeight - 12.5f, CGFLOAT_MAX);
    CGSize sizeToFit = [_bodyLabel.text sizeWithFont:_bodyLabel.font
                         constrainedToSize:constraintSize
                             lineBreakMode:_bodyLabel.lineBreakMode];

    _bodyLabel.frame = CGRectMake(kMPNotifHeight, ceilf((kMPNotifHeight - sizeToFit.height) / 2.0f) - 2.0f, ceilf(sizeToFit.width), ceilf(sizeToFit.height));
}

- (UIView *)getTopView
{
    UIView *topView = nil;
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if(window) {
        if(window.subviews.count > 0)
        {
            topView = [window.subviews objectAtIndex:0];
        }
    }
    return topView;
}

- (double)angleForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        default:
            return 0.0;
    }
}

- (void)showWithAnimation
{
    [self.view removeFromSuperview];

    UIView *topView = [self getTopView];
    if (topView) {

        double angle = [self angleForInterfaceOrientation:[self interfaceOrientation]];
        CGRect topFrame = CGRectApplyAffineTransform(topView.frame, CGAffineTransformMakeRotation((float)angle));

        [topView addSubview:self.view];

        _canPan = NO;

        self.view.frame = CGRectMake(0.0f, topFrame.size.height, topFrame.size.width, kMPNotifHeight * 3.0f);
        _position = self.view.layer.position;

        [UIView animateWithDuration:0.1f animations:^{
            self.view.frame = CGRectMake(0.0f, topFrame.size.height - kMPNotifHeight, topFrame.size.width, kMPNotifHeight * 3.0f);
        } completion:^(BOOL finished) {
            _position = self.view.layer.position;
            [self performSelector:@selector(animateImage) withObject:nil afterDelay:0.1];
            _canPan = YES;
        }];
    }
}

- (void)animateImage
{

    CGSize imageViewSize = CGSizeMake(40.0f, 40.0f);
    CGFloat duration = 0.5f;

    // Animate the circle around the image
    CGRect before = self.circleLayer.bounds;
    CGRect after = CGRectMake(0.0f, 0.0f, imageViewSize.width + (self.circleLayer->circlePadding * 2.0f), imageViewSize.height + (self.circleLayer->circlePadding * 2.0f));

    ElasticEaseOutAnimation *circleAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:[NSValue valueWithCGRect:before] endValue:[NSValue valueWithCGRect:after] andDuration:duration];
    self.circleLayer.bounds = after;
    [self.circleLayer addAnimation:circleAnimation forKey:@"bounds"];

    // Animate the image
    before = self.imageView.bounds;
    after = CGRectMake(0.0f, 0.0f, imageViewSize.width, imageViewSize.height);
    ElasticEaseOutAnimation *imageAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:[NSValue valueWithCGRect:before] endValue:[NSValue valueWithCGRect:after] andDuration:duration];
    self.imageView.layer.bounds = after;
    [self.imageView.layer addAnimation:imageAnimation forKey:@"bounds"];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    _canPan = NO;

    CGFloat duration;

    if (animated) {
        duration = 0.5f;
    } else {
        duration = 0.0f;
    }
    
    double angle = [self angleForInterfaceOrientation:[self interfaceOrientation]];
    CGRect parentFrame = CGRectApplyAffineTransform(self.view.superview.frame, CGAffineTransformMakeRotation((float)angle));

    [UIView animateWithDuration:duration animations:^{
        self.view.frame = CGRectMake(0.0f, parentFrame.size.height, parentFrame.size.width, kMPNotifHeight * 3.0f);
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
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
        } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
            if (self.view.layer.position.y > _position.y + kMPNotifHeight / 2.0f && self.delegate != nil) {
                [self.delegate notificationSmallControllerWasDismissed:self status:NO];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = _position;
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

