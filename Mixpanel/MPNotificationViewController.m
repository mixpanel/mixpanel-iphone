#import "MPNotificationViewController.h"

#import "MPNotification.h"
#import "UIColor+MPColor.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface MPNotificationViewController ()

@end

@implementation MPNotificationViewController

@end

@interface MPAlphaMaskView : UIView {

@protected
    CAGradientLayer *_maskLayer;
}

@end

@interface MPButton : UIButton

@end

@interface MPBgRadialGradientView : UIView

@end

@interface MPTakeoverNotificationViewController () {
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

@interface MPTakeoverNotificationViewController ()

@end

@implementation MPTakeoverNotificationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _backgroundImageView.image = _backgroundImage;

    if (self.notification) { //REVIEW when would it not have a notification?
        if (self.notification.image) {
            UIImage *image = [UIImage imageWithData:self.notification.image scale:2.0f];
            if (image) {
                _imageWidth.constant = image.size.width;
                _imageHeight.constant = image.size.height;
                _imageView.image = image;
            } else {
                NSLog(@"image failed to load from data: %@", self.notification.image);
            }
        }

        _titleView.text = self.notification.title;
        _bodyView.text = self.notification.body;

        if (self.notification.callToAction && [self.notification.callToAction length] > 0) {
            [_okayButton setTitle:self.notification.callToAction forState:UIControlStateNormal];
            [_okayButton sizeToFit];
        }
    }

    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    _imageView.layer.shadowOpacity = 1.0f;
    _imageView.layer.shadowRadius = 5.0f;
    _imageView.layer.shadowColor = [UIColor blackColor].CGColor;

    [_okayButton addTarget:self action:@selector(pressedOkay) forControlEvents:UIControlEventTouchUpInside];
    [_closeButton addTarget:self action:@selector(pressedClose) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [_imageDragView addGestureRecognizer:gesture];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    [self.presentingViewController dismissViewControllerAnimated:animated completion:completion];
}

- (void)viewDidLayoutSubviews
{
    [_okayButton sizeToFit];
    [_imageAlphaMaskView sizeToFit];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent; //REVIEW prob an issue in iso6, at least for ios6 sdk
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
        _bgMask.alpha = 0.0f;
        _imageView.alpha = 0.0f;
        _titleView.alpha = 0.0f;
        _bodyView.alpha = 0.0f;
        _okayButton.alpha = 0.0f;
        _closeButton.alpha = 0.0f;
    }
}

- (void)endAppearanceTransition
{
    [super endAppearanceTransition];

    NSTimeInterval duration = 0.20f;

    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 10.0f);
    transform = CGAffineTransformScale(transform, 0.9f, 0.9f);
    _imageView.transform = transform;
    _titleView.transform = transform;
    _bodyView.transform = transform;
    _okayButton.transform = transform;

    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        _titleView.transform = CGAffineTransformIdentity;
        _titleView.alpha = 1.0f;
        _bodyView.transform = CGAffineTransformIdentity;
        _bodyView.alpha = 1.0f;
        _okayButton.transform = CGAffineTransformIdentity;
        _okayButton.alpha = 1.0f;
        _imageView.transform = CGAffineTransformIdentity;
        _imageView.alpha = 1.0f;
        _bgMask.alpha = 1.0f;
    } completion:nil];

    [UIView animateWithDuration:duration delay:0.15f options:UIViewAnimationOptionCurveEaseOut animations:^{
        _closeButton.transform = CGAffineTransformIdentity;
        _closeButton.alpha = 1.0f;
    } completion:nil];
}

- (void)pressedOkay
{
    if (self.delegate) {
        [self.delegate notificationController:self wasDismissedWithStatus:YES];
    }
}

- (void)pressedClose
{
    if (self.delegate) {
        [self.delegate notificationController:self wasDismissedWithStatus:NO];
    }
}

- (void)didPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.numberOfTouches == 1) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            _viewStart = _imageView.layer.position;
            _touching = YES;
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [gesture translationInView:self.view];
            _imageView.layer.position = CGPointMake(0.3f * (translation.x) + _viewStart.x, 0.3f * (translation.y) + _viewStart.y);
        }
    }

    if (_touching && (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled)) {
        _touching = NO;
        CGPoint viewEnd = _imageView.layer.position;
        CGPoint viewDistance = CGPointMake(viewEnd.x - _viewStart.x, viewEnd.y - _viewStart.y);
        CGFloat distance = sqrtf(viewDistance.x * viewDistance.x + viewDistance.y * viewDistance.y);
        [UIView animateWithDuration:(distance / 500.0f) delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
            _imageView.layer.position = _viewStart;
        } completion:nil];
    }
}

@end

@implementation MPAlphaMaskView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super initWithCoder:aDecoder]) {
        _maskLayer = [CAGradientLayer layer];

        _maskLayer.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
                              (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
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

#define MPNotifHeight 65.0f

@interface CircleLayer : CALayer {
}

@property (nonatomic, assign) CGFloat circlePadding;

@end

@implementation CircleLayer

+ (id)layer {
    CircleLayer *cl = (CircleLayer *)[super layer];
    cl.circlePadding = 2.5f;
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

@end

@implementation ElasticEaseOutAnimation

- (id)initWithStartValue:(CGRect)start endValue:(CGRect)end andDuration:(double)duration
{
    if ((self = [super init]))
    {
        self.duration = duration;
        self.values = [self generateValuesFrom:start to:end];
    }
    return self;
}

- (NSArray *)generateValuesFrom:(CGRect)start to:(CGRect)end
{
    NSUInteger steps = (NSUInteger)ceil(60 * self.duration) + 2;
	NSMutableArray *valueArray = [NSMutableArray arrayWithCapacity:steps];
    const double increment = 1.0 / (double)(steps - 1);
    double t = 0.0;
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

@interface MPMiniNotificationViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CircleLayer *circleLayer;
@property (nonatomic, strong) UIToolbar *uiToolbarView;
@property (nonatomic, strong) UILabel *bodyLabel;

@end

@implementation MPMiniNotificationViewController

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

    UIColor *blurColor = [UIColor mp_applicationPrimaryColor];
    if (!blurColor) {
        blurColor = [UIColor mp_darkEffectColor];
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

    self.view.frame = CGRectMake(0.0f, parentFrame.size.height - MPNotifHeight, parentFrame.size.width, MPNotifHeight * 3.0f);

    // Position images
    _uiToolbarView.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    _imageView.layer.position = CGPointMake(MPNotifHeight / 2.0f, MPNotifHeight / 2.0f);

    // Position circle around image
    _circleLayer.position = self.imageView.layer.position;
    [_circleLayer setNeedsDisplay];

    // Position body label
    CGFloat offsetX = MPNotifHeight;
    _bodyLabel.frame = CGRectMake(offsetX, 12.5f, self.view.frame.size.width - offsetX - 12.5f, 0.0f);
    [_bodyLabel sizeToFit];
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

        self.view.frame = CGRectMake(0.0f, topFrame.size.height, topFrame.size.width, MPNotifHeight * 3.0f);
        _position = self.view.layer.position;

        [UIView animateWithDuration:0.1f animations:^{
            self.view.frame = CGRectMake(0.0f, topFrame.size.height - MPNotifHeight, topFrame.size.width, MPNotifHeight * 3.0f);
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
    CGRect before = _circleLayer.bounds;
    CGRect after = CGRectMake(0.0f, 0.0f, imageViewSize.width + (_circleLayer.circlePadding * 2.0f), imageViewSize.height + (_circleLayer.circlePadding * 2.0f));

    ElasticEaseOutAnimation *circleAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:before endValue:after andDuration:duration];
    _circleLayer.bounds = after;
    [_circleLayer addAnimation:circleAnimation forKey:@"bounds"];

    // Animate the image
    before = _imageView.bounds;
    after = CGRectMake(0.0f, 0.0f, imageViewSize.width, imageViewSize.height);
    ElasticEaseOutAnimation *imageAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:before endValue:after andDuration:duration];
    _imageView.layer.bounds = after;
    [_imageView.layer addAnimation:imageAnimation forKey:@"bounds"];
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
        self.view.frame = CGRectMake(0.0f, parentFrame.size.height, parentFrame.size.width, MPNotifHeight * 3.0f);
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
            [self.delegate notificationController:self wasDismissedWithStatus:YES];
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
            if (self.view.layer.position.y > _position.y + MPNotifHeight / 2.0f && self.delegate != nil) {
                [self.delegate notificationController:self wasDismissedWithStatus:NO];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = _position;
                }];
            }
        }
    }
}

@end

