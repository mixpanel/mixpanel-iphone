//
//  MPNotificationViewController.m
//  HelloMixpanel
//
//  Created by Kyle Warren on 10/18/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "MPNotificationViewController.h"

#import "MPNotification.h"

@interface MPNotificationViewController () {
    id _target;
    SEL _action;
}

@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UILabel *titleView;
@property (nonatomic, retain) IBOutlet UILabel *bodyView;
@property (nonatomic, retain) IBOutlet UIButton *okayButton;

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
    
    if (self.notification) {
        NSLog(@"notif: %@", self.notification.body);
        
        if (self.notification.images.count > 0) {
            self.imageView.image = self.notification.images[0];
        }
        
        self.titleView.text = self.notification.title;
        self.bodyView.text = self.notification.body;
    }
    
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
