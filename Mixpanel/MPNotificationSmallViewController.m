//
//  MPNotificationSmallViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotificationSmallViewController.h"

#import "MPNotification.h"

#define kMPNotifHeight 44.0f

@interface MPNotificationSmallViewController ()

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *bodyLabel;

@end

@implementation MPNotificationSmallViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithPresentedViewController:(UIViewController *)controller notification:(MPNotification *)notification
{
    self = [super initWithNibName:Nil bundle:nil];
    if (self) {
        self.parentController = controller;
        self.notification = notification;
    }
    return self;
}

- (void)setNotification:(MPNotification *)notification
{
    if (_notification) {
        [_notification release];
    }
    _notification = notification;
    
    if (_notification != nil) {
        [_notification retain];
        
        if (self.notification.image != nil) {
            self.imageView.image = [UIImage imageWithData:self.notification.image scale:2.0f];
            self.imageView.hidden = NO;
        }
        
        if (self.notification.title != nil) {
            self.titleLabel.text = self.notification.title;
            self.titleLabel.hidden = NO;
        }
        
        if (self.notification.body != nil) {
            self.bodyLabel.text = self.notification.body;
            self.bodyLabel.hidden = NO;
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bodyLabel.textColor = [UIColor whiteColor];
    self.bodyLabel.font = [UIFont systemFontOfSize:12.0f];
    
    if (self.notification != nil) {
        if (self.notification.image != nil) {
            self.imageView.image = [UIImage imageWithData:self.notification.image scale:2.0f];
            self.imageView.hidden = NO;
        } else {
            self.imageView.hidden = YES;
        }
        
        if (self.notification.title != nil) {
            self.titleLabel.text = self.notification.title;
            self.titleLabel.hidden = NO;
        } else {
            self.titleLabel.hidden = YES;
        }
        
        if (self.notification.body != nil) {
            self.bodyLabel.text = self.notification.body;
            self.bodyLabel.hidden = NO;
        } else {
            self.bodyLabel.hidden = YES;
        }
    }
    
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.bodyLabel];
	
    self.view.backgroundColor = [UIColor colorWithRed:24.0f / 255.0f green:24.0f / 255.0f blue:31.0f / 255.0f alpha:0.9f];
    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);
}

- (void)dealloc
{
    [super dealloc];
    
    self.parentController = nil;
    self.notification = nil;
    self.imageView = nil;
    self.titleLabel = nil;
    self.bodyLabel = nil;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    UIView *parentView = self.parentController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight);
    
    self.imageView.frame = CGRectMake(5.0f, 5.0f, kMPNotifHeight - 10.0f, kMPNotifHeight - 10.0f);
    CGFloat offsetX = self.imageView.frame.size.width + self.imageView.frame.origin.x + 5.0f;
    self.titleLabel.frame = CGRectMake(offsetX, 5.0f, self.view.frame.size.width - offsetX - 5.0f, 15.0f);
    self.bodyLabel.frame = CGRectMake(offsetX, 5.0f + 15.0f, self.titleLabel.frame.size.width, 15.0f);
}

- (void)willMoveToParentViewController:(UIViewController *)parent
{
    [super willMoveToParentViewController:parent];
    
    UIView *parentView = self.parentController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height, parentView.frame.size.width, kMPNotifHeight);
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    
    [UIView animateWithDuration:0.5f animations:^{
        UIView *parentView = self.parentController.view;
        self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - kMPNotifHeight, parentView.frame.size.width, kMPNotifHeight);
    }];
}

- (void)show
{
    [self willMoveToParentViewController:self.parentController];
    [self.parentController.view addSubview:self.view];
    [self.parentController addChildViewController:self];
    [self didMoveToParentViewController:self.parentController];
}

@end
