//
//  BaseTestViewController.m
//  HelloMixpanel
//
//  Created by Zihe Jia on 4/4/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//
@import Mixpanel;
#import "BaseTestViewController.h"

typedef void (^ActionBlock)(void);

@interface BaseTestViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation BaseTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.mixpanel = [Mixpanel sharedInstance];
}

#pragma mark - tableView delegate and datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.trackActionsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"trackingCellIdentifier"];
    cell.textLabel.text = self.trackActionsArray[(NSUInteger)indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ActionBlock actionBlock = self.trackActions[self.trackActionsArray[(NSUInteger)indexPath.row]];
    actionBlock();
    if (indexPath) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)presentLogMessage:(NSString *)message title:(NSString *)title
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:title
                                 message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", @"OK")
                               style:UIAlertActionStyleDefault
                               handler:nil];
    [alert addAction:okButton];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
