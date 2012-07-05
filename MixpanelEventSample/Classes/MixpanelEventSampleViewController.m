//
//  MixpanelEventSampleViewController.m
//  MixpanelEventSample
//
//

#import "MixpanelEventSampleViewController.h"
#import "MixpanelAPI.h"
@implementation MixpanelEventSampleViewController
@synthesize genderControl;
@synthesize weaponControl;

- (IBAction) registerEvent:(id)sender {
	MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
    [mixpanel setSendDeviceModel:YES];
	[mixpanel track:@"Player Create" properties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [genderControl titleForSegmentAtIndex:genderControl.selectedSegmentIndex], @"gender",
                                                 [weaponControl titleForSegmentAtIndex:weaponControl.selectedSegmentIndex], @"weapon", 
                                                 nil]];
}

- (IBAction) registerPerson:(id)sender {
    MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
    
    [mixpanel setUserProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                             [genderControl titleForSegmentAtIndex:genderControl.selectedSegmentIndex], @"gender",
                             [weaponControl titleForSegmentAtIndex:weaponControl.selectedSegmentIndex], @"weapon", 
                             nil]];
}

- (void)dealloc {
	self.genderControl = nil;
	self.weaponControl = nil;
    [super dealloc];
}

@end
