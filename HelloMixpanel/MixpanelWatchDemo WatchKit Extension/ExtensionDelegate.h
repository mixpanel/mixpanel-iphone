//
//  ExtensionDelegate.h
//  MixpanelWatchDemo WatchKit Extension
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <WatchKit/WatchKit.h>

@class Mixpanel;

@interface ExtensionDelegate : NSObject <WKExtensionDelegate>

@property (strong, nonatomic) Mixpanel *mixpanel;

@end
