//
//  TopNavViewController.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 26/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "TopNavViewController.h"

@interface TopNavViewController ()

@end

@implementation TopNavViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    NSLog(@"%@", self.viewControllers);
    return [super popViewControllerAnimated:animated];
}

- (NSArray *)popToRootViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    return [super popToViewController:viewController animated:animated];
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    return [super popToRootViewControllerAnimated:animated];
}

@end
