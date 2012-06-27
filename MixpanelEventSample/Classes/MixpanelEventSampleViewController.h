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
@property(nonatomic, retain) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, retain) IBOutlet UISegmentedControl *weaponControl;

- (IBAction) registerEvent:(id)sender;
- (IBAction) registerPerson:(id)sender;
@end

