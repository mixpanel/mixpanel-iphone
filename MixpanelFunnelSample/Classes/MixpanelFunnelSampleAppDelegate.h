//
//  MixpanelFunnelSampleAppDelegate.h
//  MixpanelFunnelSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright elfredpagan.com 2010. All rights reserved.
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

