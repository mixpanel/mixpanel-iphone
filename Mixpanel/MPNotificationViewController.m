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
    self.backgroundImageView.image = [_backgroundImage mp_applyDarkEffect];
    
    if (self.notification) {
        if (self.notification.images.count > 0) {
            self.imageView.image = self.notification.images[0];
        }
        
        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;
        
        if (self.notification.cta.length > 0) {
            [self.okayButton setTitle:self.notification.cta forState:UIControlStateNormal];
            [self.okayButton sizeToFit];
        }
    }
    
    self.okayButton.layer.backgroundColor = [UIColor colorWithRed:43.0f/255.0f green:43.0f/255.0f blue:52.0f/255.0f alpha:1.0f].CGColor;
    self.okayButton.layer.cornerRadius = 17.0f;
    self.okayButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.okayButton.layer.borderWidth = 2.0f;
    
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
    CGColorRef outerFadeColor = [UIColor colorWithWhite:1 alpha:0.1f].CGColor;
    CGColorRef innerFadeColor = [UIColor colorWithWhite:1 alpha:0.3f].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1 alpha:1].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)outerFadeColor, (id)innerFadeColor, (id)innerColor, (id)innerColor];
    // add 44 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 44.0f / self.bodyBg.bounds.size.height;
    CGFloat offset2 = 10.0f / self.bodyBg.bounds.size.height;
    CGFloat offset3 = 20.0f / self.bodyBg.bounds.size.height;
    fadeLayer.locations = @[@0, @(offset2), @(offset3), @(offset), @1];
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
    
    CGFloat offset = 44.0f / self.bodyBg.bounds.size.height;
    CGFloat offset2 = 10.0f / self.bodyBg.bounds.size.height;
    CGFloat offset3 = 20.0f / self.bodyBg.bounds.size.height;
    ((CAGradientLayer *) self.bodyBg.layer.mask).locations = @[@0, @(offset2), @(offset3), @(offset), @1];
    self.bodyBg.layer.mask.bounds = self.bodyBg.bounds;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
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
