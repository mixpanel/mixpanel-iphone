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

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet MixpanelEventSampleViewController *viewController;

@end

