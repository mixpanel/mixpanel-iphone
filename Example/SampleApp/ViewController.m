//
//  ViewController.m
//  SampleApp
//
//  Created by Ram Amar on 25/08/2015.
//  Copyright © 2015 Alooma. All rights reserved.
//

#import "ViewController.h"
#import <AloomaIos/Alooma.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendEventButtonClicked:(id)sender {
    [[Alooma sharedInstance] track:self.eventTextField.text];
}

- (IBAction)sendEventsBulkButtonClicked:(id)sender {
    for (int i = 0 ; i < 100 ; i++) {
        [[Alooma sharedInstance] track:[self.eventTextField.text stringByAppendingFormat:@" %d", i]];
    }
}

- (IBAction)sendArgumentsEventButtonClicked:(id)sender {
    [[Alooma sharedInstance] trackCustomEvent:@{ @"key_str" : @"val1", @"key_float" : @(1.5), @"key_bool" : @(YES), @"key_int" : @(1983), @"key_date" : [NSDate date], @"key_array" : @[@"arr1", @"arr2", @"arr3"]}];
}

- (IBAction)sendTextArgsEventButtonClicked:(id)sender {
    [[Alooma sharedInstance] track:self.eventTextField.text customEvent:@{ @"key1" : @"val1", @"key2" : @"val2", @"key3" : @"val3", @"key4" : @"val4", @"key5" : @"val5"}];
}


@end
