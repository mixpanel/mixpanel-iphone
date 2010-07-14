//
//  MixpanelFunnelSampleViewController.m
//  MixpanelFunnelSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright elfredpagan.com 2010. All rights reserved.
//

#import "MixpanelFunnelSampleViewController.h"
#import "MixpanelAPI.h"
@implementation MixpanelFunnelSampleViewController
@synthesize itemControl;
#pragma mark -
#pragma mark Mixpanel Calls

-(void) productViewLoaded {
	MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
	[mixpanel trackFunnel:@"In App Purchase" step:1 goal:@"Product List"];
	// product list code.
}

-(void) selectProduct:(NSString*) product {
	MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
	[mixpanel trackFunnel:@"In App Purchase" 
					 step:2 
					 goal:@"View Product"
			   properties:[NSDictionary dictionaryWithObject:product forKey:@"product"]];
	// view product code.
}

-(void) buyProduct:(NSString*) product {
	MixpanelAPI *mixpanel = [MixpanelAPI sharedAPI];
	[mixpanel trackFunnel:@"In App Purchase" 
					 step:3 
					 goal:@"Buy Product"
			   properties:[NSDictionary dictionaryWithObject:product forKey:@"product"]];
	// buy product code.
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	[self productViewLoaded];
}

- (IBAction) segmentControlChanged:(UISegmentedControl*) control {
	NSString *product = [control titleForSegmentAtIndex:control.selectedSegmentIndex];
	[self selectProduct:product];
}
- (IBAction) trackProduct {
	NSString *product = [itemControl titleForSegmentAtIndex:itemControl.selectedSegmentIndex];
	[self buyProduct:product];
}
- (void)dealloc {
	self.itemControl = nil;
    [super dealloc];
}

@end
