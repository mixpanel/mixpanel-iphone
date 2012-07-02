//
//  MixpanelEventSampleAppDelegate.h
//  MixpanelEventSample
//
//

#import <UIKit/UIKit.h>

@class MixpanelEventSampleViewController;
@class MixpanelAPI;
@interface MixpanelEventSampleAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    MixpanelEventSampleViewController *viewController;
	MixpanelAPI *mixpanel;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MixpanelEventSampleViewController *viewController;

@end
