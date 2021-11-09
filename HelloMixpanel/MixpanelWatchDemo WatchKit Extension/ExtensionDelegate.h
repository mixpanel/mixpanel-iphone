//
//  ExtensionDelegate.h
//  MixpanelWatchDemo WatchKit Extension
//
//  Created by ZIHE JIA on 11/8/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import <WatchKit/WatchKit.h>

@class Mixpanel;

@interface ExtensionDelegate : NSObject <WKExtensionDelegate>

@property (strong, nonatomic) Mixpanel *mixpanel;

@end
