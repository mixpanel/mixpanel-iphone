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

@interface ViewController ()

@property(nonatomic, retain) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, retain) IBOutlet UISegmentedControl *weaponControl;

- (IBAction)trackEvent:(id)sender;
- (IBAction)sendPeopleRecord:(id)sender;

@end

@implementation ViewController

- (void)dealloc
{
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
    [mixpanel.people identify:mixpanel.distinctId];
}

@end
