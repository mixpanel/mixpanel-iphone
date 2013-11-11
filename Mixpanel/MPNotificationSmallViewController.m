//
//  MPNotificationSmallViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 11/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotificationSmallViewController.h"

#import "MPNotification.h"

@interface MPNotificationSmallViewController ()

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

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.view.backgroundColor = [UIColor blueColor];
    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    UIView *parentView = self.parentController.view;
    self.view.frame = CGRectMake(0.0f, parentView.frame.size.height - 30.0f, parentView.frame.size.width, 30.0f);
}

- (void)show
{
    [self willMoveToParentViewController:self.parentController];
    [self.parentController.view addSubview:self.view];
    [self.parentController addChildViewController:self];
    [self didMoveToParentViewController:self.parentController];
}

@end
