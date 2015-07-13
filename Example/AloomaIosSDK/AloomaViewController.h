//
//  AloomaViewController.h
//  AloomaIosSDK
//
//  Created by Alooma on 06/28/2015.
//  Copyright (c) 2014 Alooma. All rights reserved.
//

@import UIKit;

@interface AloomaViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *eventTextField;

- (IBAction)sendEventButtonClicked:(id)sender;
- (IBAction)sendEventsBulkButtonClicked:(id)sender;
- (IBAction)sendArgumentsEventButtonClicked:(id)sender;
- (IBAction)sendTextArgsEventButtonClicked:(id)sender;

@end
