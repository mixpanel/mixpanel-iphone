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

@interface MPNotificationViewController () {
    id _target;
    SEL _action;
}

@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UILabel *titleView;
@property (nonatomic, retain) IBOutlet UILabel *bodyView;
@property (nonatomic, retain) IBOutlet UIButton *okayButton;
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
        NSLog(@"notif: %@", self.notification.body);
        
        if (self.notification.images.count > 0) {
            self.imageView.image = self.notification.images[0];
        }
        
        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;
        [self.okayButton setTitle:self.notification.cta forState:UIControlStateNormal];
        [self.okayButton sizeToFit];
    }
    
    self.okayButton.layer.cornerRadius = 15.0f;
    self.okayButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.okayButton.layer.borderWidth = 2.0f;
    
//    self.bodyBg.layer.shadowOffset = CGSizeMake(0.0f, -20.0f);
//    self.bodyBg.layer.shadowOpacity = 1.0f;
//    self.bodyBg.layer.shadowRadius = 5.0f;
//    self.bodyBg.layer.shadowColor = [UIColor blackColor].CGColor;
    
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1 alpha:1].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor];
    // add 20 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 44 / self.bodyBg.bounds.size.height;
    fadeLayer.locations = @[@0, @(0 + offset), @(1 - offset), @1];
    fadeLayer.bounds = self.bodyBg.bounds;
    fadeLayer.anchorPoint = CGPointZero;
    self.bodyBg.layer.mask = fadeLayer;
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.imageView.layer.shadowOpacity = 1.0f;
    self.imageView.layer.shadowRadius = 5.0f;
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    //self.bodyBg.backgroundColor = [UIColor blackColor];
    
    [self.okayButton addTarget:self action:@selector(pressedOkay) forControlEvents:UIControlEventTouchDown];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.titleView sizeToFit];
    [self.bodyView sizeToFit];
    //[self.okayButton.titleLabel sizeToFit];
    [self.okayButton sizeToFit];
}

- (void)pressedOkay
{
    if (_target) {
        [_target performSelector:_action withObject:self];
    }
}

- (void)setDismissTarget:(id)target action:(SEL)action
{
    _target = target;
    _action = action;
}

@end
