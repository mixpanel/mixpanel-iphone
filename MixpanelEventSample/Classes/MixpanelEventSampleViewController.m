//
//  MixpanelEventSampleViewController.m
//  MixpanelEventSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright mixpanel.com 2010. All rights reserved.
//

#import "MixpanelEventSampleViewController.h"
#import "MixpanelAPI.h"
@implementation MixpanelEventSampleViewController
@synthesize genderControl;
@synthesize weaponControl;

- (IBAction) registerEvent:(id)sender {
	MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
	[mixpanel track:@"Player Create" 
		 properties:[NSDictionary dictionaryWithObjectsAndKeys:[genderControl titleForSegmentAtIndex:genderControl.selectedSegmentIndex], @"gender",
															[weaponControl titleForSegmentAtIndex:weaponControl.selectedSegmentIndex], @"weapon", nil]];
}
- (void)dealloc {
	self.genderControl = nil;
	self.weaponControl = nil;
    [super dealloc];
}

@end
