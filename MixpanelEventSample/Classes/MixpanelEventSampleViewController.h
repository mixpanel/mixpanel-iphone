//
//  MixpanelEventSampleViewController.h
//  MixpanelEventSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright mixpanel.com 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MixpanelEventSampleViewController : UIViewController {
	UISegmentedControl *genderControl;
	UISegmentedControl *weaponControl;
}
@property(nonatomic, retain) IBOutlet UISegmentedControl *genderControl;
@property(nonatomic, retain) IBOutlet UISegmentedControl *weaponControl;

- (IBAction) registerEvent:(id)sender;
@end

