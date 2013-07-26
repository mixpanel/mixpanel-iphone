//
//  MXPMainWindowController.m
//  HelloMixpanelDesktop
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


#import <QuartzCore/QuartzCore.h>
#import "MXPMainWindowController.h"
#import "Mixpanel.h"

@interface MXPMainWindowController ()
/* Will draw the background of the window */
-(CALayer *)_addGradientBackground;
@end

@implementation MXPMainWindowController

#pragma mark * Life cycle
- (id)initWithWindowNibName:(NSString *)windowNibName
{
    self = [super initWithWindowNibName:@"MXPMainWindow"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self _addGradientBackground];    
}

#pragma mark * IB Action
- (IBAction)trackEvent:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel track:@"Player Create" properties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [self.genderControl labelForSegment:self.genderControl.selectedSegment], @"gender",
                                                 [self.weaponControl labelForSegment:self.weaponControl.selectedSegment], @"weapon",
                                                 nil]];

}

- (IBAction)sendPeopleRecord:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people set:[NSDictionary dictionaryWithObjectsAndKeys:
                          [self.genderControl labelForSegment:self.genderControl.selectedSegment], @"gender",
                          [self.weaponControl labelForSegment:self.weaponControl.selectedSegment], @"weapon",
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

#pragma mark * Private methods

/* Will draw the background of the window : Be careful works only on 10.8 */
-(CALayer *)_addGradientBackground
{
    [self.window.contentView setWantsLayer:YES];
    ((NSView *)self.window.contentView).layer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    CALayer *tmpLayer = [CALayer layer];
    tmpLayer.name = @"background";
    tmpLayer.delegate = self;
//    tmpLayer.bounds = self.window.bounds;
    tmpLayer.position = CGPointZero;
    tmpLayer.needsDisplayOnBoundsChange = YES;
    [tmpLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth
                                                       relativeTo:@"superlayer" attribute:kCAConstraintWidth]];
    [tmpLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX
                                                       relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
    
    [tmpLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidY
                                                       relativeTo:@"superlayer" attribute:kCAConstraintMidY]];
    
    [tmpLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintHeight
                                                       relativeTo:@"superlayer" attribute:kCAConstraintHeight]];
    
    NSImage*    backgroundImage = [NSImage imageNamed:@"grid"];
    
    tmpLayer.backgroundColor = [[NSColor colorWithPatternImage:backgroundImage] CGColor];

    [((NSView *)self.window.contentView).layer insertSublayer:tmpLayer atIndex:0];
    return tmpLayer;
}



@end
