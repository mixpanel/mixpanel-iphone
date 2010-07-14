//
//  MixpanelEventSampleAppDelegate.h
//  MixpanelEventSample
//
//  Created by Elfred Pagan on 7/9/10.
//  Copyright mixpanel.com 2010. All rights reserved.
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

