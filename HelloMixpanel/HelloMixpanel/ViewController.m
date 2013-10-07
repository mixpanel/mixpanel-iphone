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
#import "MPSurvey.h"

#import "ViewController.h"

@interface ViewController ()

@property(nonatomic, retain) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, retain) IBOutlet UISegmentedControl *weaponControl;

@end

@implementation ViewController

- (void)dealloc
{
    self.genderControl = nil;
    self.weaponControl = nil;
    [super dealloc];
}

- (IBAction)trackEvent:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    NSString *gender = [self.genderControl titleForSegmentAtIndex:(NSUInteger)self.genderControl.selectedSegmentIndex];
    NSString *weapon = [self.weaponControl titleForSegmentAtIndex:(NSUInteger)self.weaponControl.selectedSegmentIndex];
    [mixpanel track:@"Player Create" properties:@{@"gender": gender, @"weapon": weapon}];
}

- (IBAction)setPeopleProperties:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    NSString *gender = [self.genderControl titleForSegmentAtIndex:(NSUInteger)self.genderControl.selectedSegmentIndex];
    NSString *weapon = [self.weaponControl titleForSegmentAtIndex:(NSUInteger)self.weaponControl.selectedSegmentIndex];
    [mixpanel.people set:@{
                           @"gender": gender,
                           @"weapon": weapon,
                           @"$first_name": @"Demo",
                           @"$last_name": @"User",
                           @"$email": @"user@example.com"
                           }];
    // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
    // we're using the automatically generated distinct ID from event tracking, based on the device's MAC address.
    // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
    // Note that the call to Mixpanel People identify: can come after properties have been set. We queue them until
    // identify: is called and flush them at that time. That way, you can set properties before a user is logged in
    // and identify them once you know their user ID.
    [mixpanel identify:mixpanel.distinctId];
}

- (IBAction)showSurvey:(id)sender
{
    NSDictionary *object = @{
                             @"version": @0,
                             @"id": @1,
                             @"collections": @[@{@"id": @2}],
                             @"questions": @[
                                     @{
                                         @"id": @3,
                                         @"type": @"multiple_choice",
                                         @"prompt": @"If we discontinued our service, how much would you care? Or if this was a really really really long long question?",
                                         @"extra_data": @{
                                                 @"$choices": @[
                                                         @"A lot",
                                                         @"A little",
                                                         @"Not at all",
                                                         @"I'd prefer you didn't exist... and I like really, really long answers",
                                                         [NSNull null]
                                                         ]
                                                 }
                                         },
                                     @{
                                         @"id": @7,
                                         @"type": @"text",
                                         @"prompt": @"Anything else to add?",
                                         @"extra_data": @{}
                                         },
                                     @{
                                         @"id": @3,
                                         @"type": @"multiple_choice",
                                         @"prompt": @"If we discontinued our service, how much would you care? A lot or a little?",
                                         @"extra_data": @{
                                                 @"$choices": @[
                                                         @"A lot",
                                                         @"A little",
                                                         @"Not at all",
                                                         @"I'd prefer you didn't exist",
                                                         [NSNull null]
                                                         ]
                                                 }
                                         },
                                     @{
                                         @"id": @7,
                                         @"type": @"text",
                                         @"prompt": @"Another text question djklsfjjs kladfj lsadkfj kldsajf kladsjf klasjf dklasj dfklajsd fklajs dfklj askldfj aklsdfj aslkjf ;adkslfj lasjflkasjflk;ajsflk ajsfdlk ajsdfklj asdlkfj adsklfj askldfj aklsdfj adklsfj adklsfj kladsj flasdj f",
                                         @"extra_data": @{}
                                         },
                                     @{
                                         @"id": @4,
                                         @"type": @"multiple_choice",
                                         @"prompt": @"How many employees does your company have?",
                                         @"extra_data": @{
                                                 @"$choices": @[
                                                         @1,
                                                         @1.5,
                                                         @100,
                                                         @1000,
                                                         @10000,
                                                         @(-2.0),
                                                         @33333333333.33,
                                                         @9,
                                                         @2314,
                                                         @2
                                                         ]
                                                 }
                                         },
                                     @{
                                         @"id": @6,
                                         @"type": @"multiple_choice",
                                         @"prompt": @"Is this question too long or just long enough to be effective in getting to the exact point we were trying to get across when engaging you in as efficient a manner as possible?",
                                         @"property": @"Promoter",
                                         @"extra_data": @{
                                                 @"$choices": @[
                                                         @YES,
                                                         @NO
                                                         ]
                                                 }
                                         }
                                     ]
                             };
    MPSurvey *survey = [MPSurvey surveyWithJSONObject:object];
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel showSurvey:survey];
}

- (IBAction)changeBackgroundColor:(id)sender
{
    NSArray *colors = @[
                        [UIColor redColor],
                        [UIColor greenColor],
                        [UIColor blueColor],
                        [UIColor yellowColor],
                        [UIColor whiteColor],
                        [UIColor blackColor]
                        ];
    self.view.backgroundColor = colors[arc4random() % [colors count]];
}

@end
