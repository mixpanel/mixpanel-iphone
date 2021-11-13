//
//  BaseTestViewController.h
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//
@import Mixpanel;
#import <UIKit/UIKit.h>

@interface BaseTestViewController : UIViewController

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSDictionary *trackActions;
@property (nonatomic, strong) NSArray *trackActionsArray;
@property (nonatomic, strong) Mixpanel *mixpanel;

- (void)presentLogMessage:(NSString *)message title:(NSString *)title;

@end
