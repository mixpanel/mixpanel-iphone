#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "UIView+MPHelpers.h"
#import "MPLogger.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"
#import "UIColor+MPColor.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "MPFoundation.h"

#define MPNotifHeight 65.0f


@interface CircleLayer : CALayer {}

@property (nonatomic, assign) CGFloat circlePadding;

@end

@interface ElasticEaseOutAnimation : CAKeyframeAnimation {}

- (instancetype)initWithStartValue:(CGRect)start endValue:(CGRect)end andDuration:(double)duration;

@end

@interface GradientMaskLayer : CAGradientLayer {}

@end

@interface MPAlphaMaskView : UIView {

@protected
    CAGradientLayer *_maskLayer;
}

@end

@interface MPBgRadialGradientView : UIView

@end

@interface MPActionButton : UIButton

@property (nonatomic, assign) BOOL isLight;

@end

@interface MPNotificationViewController ()

@end

@implementation MPNotificationViewController

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    return;
}

@end

@interface MPTakeoverNotificationViewController () {
    CGPoint _viewStart;
    BOOL _touching;
}

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet UILabel *titleView;
@property (nonatomic, strong) IBOutlet UILabel *bodyView;
@property (nonatomic, strong) IBOutlet MPActionButton *okayButton;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, strong) IBOutlet UIView *viewMask;

@end

@interface MPTakeoverNotificationViewController ()

@end

@implementation MPTakeoverNotificationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (self.notification) {
        if (self.notification.image) {
            UIImage *image = [UIImage imageWithData:self.notification.image scale:2.0f];
            if (image) {
                self.imageView.image = image;
            } else {
                MixpanelError(@"image failed to load from data: %@", self.notification.image);
            }
        }

        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;

        if (self.notification.callToAction.length > 0) {
            [self.okayButton setTitle:self.notification.callToAction forState:UIControlStateNormal];
        }
        
        if ([self.notification.style isEqualToString:@"light"]) {
            self.viewMask.backgroundColor = [UIColor whiteColor];
            self.titleView.textColor = [UIColor colorWithRed:92/255.0 green:101/255.0 blue:120/255.0 alpha:1];
            self.bodyView.textColor = [UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1];
            self.okayButton.isLight = YES;
            [self.okayButton setTitleColor:[UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1] forState:UIControlStateNormal];
            self.okayButton.layer.borderColor = [UIColor colorWithRed:218/255.0 green:223/255.0 blue:232/255.0 alpha:1].CGColor;
            UIImage *origImage = [self.closeButton imageForState:UIControlStateNormal];
            id tintedImage = [origImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.closeButton setImage:tintedImage forState:UIControlStateNormal];
            self.closeButton.tintColor = [UIColor colorWithRed:217/255.0 green:217/255.0 blue:217/255.0 alpha:1];
        }
    }
    
    self.backgroundImageView.image = self.backgroundImage;
    
    self.imageView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.imageView.layer.shadowOpacity = 1.0f;
    self.imageView.layer.shadowRadius = 5.0f;
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.viewMask.clipsToBounds = YES;
    self.viewMask.layer.cornerRadius = 6.f;
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    [self.presentingViewController dismissViewControllerAnimated:animated completion:completion];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.okayButton.center = CGPointMake(CGRectGetMidX(self.okayButton.superview.bounds), self.okayButton.center.y);
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (IBAction)pressedOkay
{
    if ([self.delegate respondsToSelector:@selector(notificationController:wasDismissedWithStatus:)]) {
        [self.delegate notificationController:self wasDismissedWithStatus:YES];
    }
}

- (IBAction)pressedClose
{
    if ([self.delegate respondsToSelector:@selector(notificationController:wasDismissedWithStatus:)]) {
        [self.delegate notificationController:self wasDismissedWithStatus:NO];
    }
}

- (IBAction)didPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.numberOfTouches == 1) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            _viewStart = self.imageView.layer.position;
            _touching = YES;
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [gesture translationInView:self.view];
            self.imageView.layer.position = CGPointMake(0.3f * translation.x + _viewStart.x, 0.3f * translation.y + _viewStart.y);
        }
    }

    if (_touching && (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled)) {
        _touching = NO;
        CGPoint viewEnd = self.imageView.layer.position;
        CGPoint viewDistance = CGPointMake(viewEnd.x - _viewStart.x, viewEnd.y - _viewStart.y);
        CGFloat distance = (CGFloat)sqrt(viewDistance.x * viewDistance.x + viewDistance.y * viewDistance.y);
        [UIView animateWithDuration:(distance / 500.0f) delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.imageView.layer.position = self->_viewStart;
        } completion:nil];
    }
}

@end

@interface MPMiniNotificationViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
    BOOL _isBeingDismissed;
}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CircleLayer *circleLayer;
@property (nonatomic, strong) UILabel *bodyLabel;

@end

@implementation MPMiniNotificationViewController

static const NSUInteger MPMiniNotificationSpacingFromBottom = 10;

- (void)viewDidLoad
{
    [super viewDidLoad];

    _canPan = YES;
    _isBeingDismissed = NO;
    self.view.clipsToBounds = YES;

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.imageView.layer.masksToBounds = YES;

    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bodyLabel.textColor = [UIColor whiteColor];
    self.bodyLabel.backgroundColor = [UIColor clearColor];
    self.bodyLabel.font = [UIFont systemFontOfSize:14.0f];
    self.bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.bodyLabel.numberOfLines = 0;

    [self initializeMiniNotification];

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
        
        if ([self.notification.style isEqualToString:@"light"]) {
            self.view.backgroundColor = [UIColor whiteColor];
            self.bodyLabel.textColor = [UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1];
            UIImage *origImage = self.imageView.image;
            id tintedImage = [origImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.imageView.image = tintedImage;
            self.imageView.tintColor = [UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1];
            self.view.layer.borderColor = [UIColor colorWithRed:218/255.0 green:223/255.0 blue:232/255.0 alpha:1].CGColor;
            self.view.layer.borderWidth = 1;
        }
    }

    [self.view addSubview:self.imageView];
    [self.view addSubview:self.bodyLabel];

    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    gesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:gesture];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)initializeMiniNotification {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.901f];
    self.view.backgroundColor = self.backgroundColor;
}

- (void)viewWillLayoutSubviews
{
    UIView *parentView = self.view.superview;
    CGRect parentFrame = parentView.frame;

    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.view.frame = CGRectMake(15, parentFrame.size.height - MPNotifHeight - MPMiniNotificationSpacingFromBottom, parentFrame.size.width - 30, MPNotifHeight);
    } else {
        self.view.frame = CGRectMake(parentFrame.size.width/4, parentFrame.size.height - MPNotifHeight - MPMiniNotificationSpacingFromBottom, parentFrame.size.width/2, MPNotifHeight);
    }
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 6.f;

    // Position images
    self.imageView.layer.position = CGPointMake(MPNotifHeight / 2.0f, MPNotifHeight / 2.0f);

    // Position circle around image
    self.circleLayer.position = self.imageView.layer.position;
    [self.circleLayer setNeedsDisplay];

    // Position body label
    CGSize constraintSize = CGSizeMake(self.view.frame.size.width - MPNotifHeight - 12.5f, CGFLOAT_MAX);
    CGSize sizeToFit = [self.bodyLabel.text boundingRectWithSize:constraintSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName: self.bodyLabel.font}
                                                         context:nil].size;

    self.bodyLabel.frame = CGRectMake(MPNotifHeight, (CGFloat)ceil((MPNotifHeight - sizeToFit.height) / 2.0f) - 2.0f, (CGFloat)ceil(sizeToFit.width), (CGFloat)ceil(sizeToFit.height));
}

- (UIView *)getTopView
{
    UIView *topView = nil;
    for (UIView *subview in [UIApplication sharedApplication].keyWindow.subviews) {
        if (!subview.hidden && subview.alpha > 0 && subview.frame.size.width > 0 && subview.frame.size.height > 0) {
            topView = subview;
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
        CGRect topFrame = topView.frame;
        [topView addSubview:self.view];

        _canPan = NO;

        self.view.frame = CGRectMake(0.0f, topFrame.size.height, topFrame.size.width, MPNotifHeight * 3.0f);
        _position = self.view.layer.position;

        [UIView animateWithDuration:0.1f animations:^{
            self.view.frame = CGRectMake(0.0f, topFrame.size.height - MPNotifHeight, topFrame.size.width, MPNotifHeight * 3.0f);
        } completion:^(BOOL finished) {
            self->_position = self.view.layer.position;
            [self performSelector:@selector(animateImage) withObject:nil afterDelay:0.1];
            self->_canPan = YES;
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

    if (!_isBeingDismissed) {
        _isBeingDismissed = YES;
        
        CGFloat duration = animated ? 0.5f : 0.f;
        CGRect parentFrame = self.view.superview.frame;
        
        [UIView animateWithDuration:duration
                         animations:^{
                             self.view.frame = CGRectMake(self.view.frame.origin.x, parentFrame.size.height, self.view.frame.size.width, self.view.frame.size.height);
                         } completion:^(BOOL finished) {
                             [self.view removeFromSuperview];
                             if (completion) {
                                 completion();
                             }
                         }];
    }
}

- (void)didTap:(UITapGestureRecognizer *)gesture
{
    if (!_isBeingDismissed && gesture.state == UIGestureRecognizerStateEnded) {
        [self.delegate notificationController:self wasDismissedWithStatus:YES];
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
            id strongDelegate = self.delegate;
            if (self.view.layer.position.y > _position.y + MPNotifHeight / 2.0f && strongDelegate != nil) {
                [strongDelegate notificationController:self wasDismissedWithStatus:NO];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = self->_position;
                }];
            }
        }
    }
}

@end

@implementation MPAlphaMaskView

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        _maskLayer = [GradientMaskLayer layer];
        [self.layer setMask:_maskLayer];
        self.opaque = NO;
        _maskLayer.opaque = NO;
        _maskLayer.needsDisplayOnBoundsChange = YES;
        [_maskLayer setNeedsDisplay];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_maskLayer setFrame:self.bounds];
}

@end

@implementation MPActionButton

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.layer.cornerRadius = 5.0f;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2.0f;
    }

    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        self.layer.borderColor = [UIColor grayColor].CGColor;
    } else {
        if (self.isLight) {
            self.layer.borderColor = [UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1].CGColor;
        } else {
            self.layer.borderColor = [UIColor whiteColor].CGColor;
        }
    }

    [super setHighlighted:highlighted];
}

@end

@implementation MPBgRadialGradientView

- (void)drawRect:(CGRect)rect
{
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGSize circleSize = CGSizeMake(center.y * 2.0f, center.y * 2.0f);
    CGRect circleFrame = CGRectMake(center.x - center.y, 0.0f, circleSize.width, circleSize.height);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);

    CGColorRef colorRef = [UIColor colorWithRed:24.0f / 255.0f green:24.0f / 255.0f blue:31.0f / 255.0f alpha:0.94f].CGColor;
    CGContextSetFillColorWithColor(ctx, colorRef);
    CGContextFillRect(ctx, self.bounds);

    CGContextSetBlendMode(ctx, kCGBlendModeCopy);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[] = {96.0f / 255.0f, 96.0f / 255.0f, 124.0f / 255.0f, 0.94f,
        72.0f / 255.0f, 72.0f / 255.0f, 93.0f / 255.0f, 0.94f,
        24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.94f,
        24.0f / 255.0f, 24.0f / 255.0f, 31.0f / 255.0f, 0.94f};
    CGFloat locs[] = {0.0f, 0.1f, 0.75, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, comps, locs, 4);

    CGContextAddEllipseInRect(ctx, circleFrame);
    CGContextClip(ctx);

    CGContextDrawRadialGradient(ctx, gradient, center, 0.0f, center, circleSize.width / 2.0f, kCGGradientDrawsAfterEndLocation);


    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);

    CGContextRestoreGState(ctx);
}

@end

@implementation CircleLayer

+ (instancetype)layer {
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

@implementation GradientMaskLayer

- (void)drawInContext:(CGContextRef)ctx
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGFloat components[] = {
        1.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.9f,
        1.0f, 0.0f};

    CGFloat locations[] = {0.0f, 0.7f, 0.8f, 1.0f};

    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 7);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(5.0f, self.bounds.size.height), (CGGradientDrawingOptions)0);


    NSUInteger bits = (NSUInteger)fabs(self.bounds.size.width) * (NSUInteger)fabs(self.bounds.size.height);
    char *rgba = (char *)malloc(bits);
    srand(124);

    for (NSUInteger i = 0; i < bits; ++i) {
        rgba[i] = (rand() % 8);
    }

    CGContextRef noise = CGBitmapContextCreate(rgba, (NSUInteger)fabs(self.bounds.size.width), (NSUInteger)fabs(self.bounds.size.height), 8, (NSUInteger)fabs(self.bounds.size.width), NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    CGImageRef image = CGBitmapContextCreateImage(noise);

    CGContextSetBlendMode(ctx, kCGBlendModeSourceOut);
    CGContextDrawImage(ctx, self.bounds, image);

    CGImageRelease(image);
    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);
    CGContextRelease(noise);
    free(rgba);
}

@end

@implementation ElasticEaseOutAnimation

- (instancetype)initWithStartValue:(CGRect)start endValue:(CGRect)end andDuration:(double)duration
{
    if ((self = [super init])) {
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
