//
//  MixpanelFunnelSampleAppDelegate.h
//  MixpanelFunnelSample
//
//

#import <UIKit/UIKit.h>

@class MixpanelFunnelSampleViewController;
@class MixpanelAPI;
@interface MixpanelFunnelSampleAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    MixpanelFunnelSampleViewController *viewController;
	MixpanelAPI *mixpanel;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MixpanelFunnelSampleViewController *viewController;

@end

