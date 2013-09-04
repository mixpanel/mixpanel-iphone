//
// ViewController.m
// HelloMixpanel
//
// Copyright 2012 Mixpanel
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Mixpanel.h"

#import "ViewController.h"

@interface ViewController () {
    UITextField *aliasTextField;
}

@property(nonatomic, retain) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, retain) IBOutlet UISegmentedControl *weaponControl;
@property(nonatomic, retain) IBOutlet UISwitch *enabledSwitch;

- (IBAction)trackEvent:(id)sender;
- (IBAction)sendPeopleRecord:(id)sender;
- (IBAction)toggleEnabled:(UISwitch *)sender;
- (IBAction)aliasUser:(id)sender;
@end

@implementation ViewController

- (void)dealloc
{
    aliasTextField = nil;
    self.genderControl = nil;
    self.weaponControl = nil;
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"grid.png"]];
    UIScrollView *tempScrollView = (UIScrollView *)self.view;
    tempScrollView.contentSize = CGSizeMake(320, 342);
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (IBAction)toggleEnabled:(UISwitch *)sender {
   if(sender.on)
       [[Mixpanel sharedInstance] enable];
   else {
       // This disables all tracking events
       // To disable specific events call disable: with an array of event names to disable.
       [[Mixpanel sharedInstance] disable];
   }
}

- (IBAction)aliasUser:(id)sender {
    UIAlertView *aliasAlertView = [[[UIAlertView alloc] initWithTitle:@"Alias User? \nTypically your own internal ID for the user.\n\n\n"
                                                          message:@""
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"OK", nil] autorelease];

    aliasTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 110.0, 260.0, 35.0)];
    [aliasTextField setBackgroundColor:[UIColor whiteColor]];
    aliasTextField.placeholder = @"alias";
    aliasTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    aliasTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [aliasAlertView addSubview:aliasTextField];
    aliasAlertView.tag = 999;
    [aliasAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == 999) {
        NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
        if([title isEqualToString:@"OK"]) {
            NSString *alias = aliasTextField.text;

            // Aliases the specified ID with users distinct ID
            // Use [[Mixpanel sharedInstance] alias:alias original:original]; if you want to specify the original ID to alias
            // This calls identify internally after creating the alias
            [[Mixpanel sharedInstance] alias:alias];
        }
    }
}


- (IBAction)trackEvent:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel track:@"Player Create" properties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [self.genderControl titleForSegmentAtIndex:self.genderControl.selectedSegmentIndex], @"gender",
                                                 [self.weaponControl titleForSegmentAtIndex:self.weaponControl.selectedSegmentIndex], @"weapon",
                                                 nil]];
}

- (IBAction)sendPeopleRecord:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people set:[NSDictionary dictionaryWithObjectsAndKeys:
                          [self.genderControl titleForSegmentAtIndex:self.genderControl.selectedSegmentIndex], @"gender",
                          [self.weaponControl titleForSegmentAtIndex:self.weaponControl.selectedSegmentIndex], @"weapon",
                          @"Demo", @"$first_name",
                          @"User", @"$last_name",
                          @"user@example.com", @"$email",
                          nil]];
    // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
    // we're using the automatically generated distinct ID from event tracking, based on the device's MAC address.
    // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
    // Note that the call to Mixpanel People identify: can come after properties have been set. We queue them until
    // identify: is called and flush them at that time. That way, you can set properties before a user is logged in
    // and identify them once you know their user ID.
    [mixpanel identify:mixpanel.distinctId];
}

@end
