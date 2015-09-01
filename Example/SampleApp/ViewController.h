//
//  ViewController.h
//  SampleApp
//
//  Created by Ram Amar on 25/08/2015.
//  Copyright © 2015 Alooma. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *eventTextField;

- (IBAction)sendEventButtonClicked:(id)sender;
- (IBAction)sendEventsBulkButtonClicked:(id)sender;
- (IBAction)sendArgumentsEventButtonClicked:(id)sender;
- (IBAction)sendTextArgsEventButtonClicked:(id)sender;

@end

