//
//  MixpanelFunnelSampleViewController.h
//  MixpanelFunnelSample
//

#import <UIKit/UIKit.h>

@interface MixpanelFunnelSampleViewController : UIViewController {
	UISegmentedControl *itemControl;
}
@property(nonatomic, retain)IBOutlet UISegmentedControl *itemControl;
- (IBAction) segmentControlChanged:(UISegmentedControl*) control;
- (IBAction) trackProduct;
@end

