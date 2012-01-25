//
//  MixpanelEventSampleViewController.h
//  MixpanelEventSample
//
//

#import <UIKit/UIKit.h>

@interface MixpanelEventSampleViewController : UIViewController {
	UISegmentedControl *genderControl;
	UISegmentedControl *weaponControl;
}
@property(nonatomic, strong) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, strong) IBOutlet UISegmentedControl *weaponControl;

- (IBAction) registerEvent:(id)sender;
@end

