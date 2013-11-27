//
//  HomeViewController.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 26/11/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "HomeViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPLogo.png"]];
}


@end
