//
//  MixpanelFunnelSampleViewController.h
//  MixpanelFunnelSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright elfredpagan.com 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MixpanelFunnelSampleViewController : UIViewController {
	UISegmentedControl *itemControl;
}
@property(nonatomic, retain)IBOutlet UISegmentedControl *itemControl;
- (IBAction) segmentControlChanged:(UISegmentedControl*) control;
- (IBAction) trackProduct;
@end

