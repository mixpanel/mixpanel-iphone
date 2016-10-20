//
//  ExtensionDelegate.h
//  HelloMixpanelWatch Extension
//
//  Created by Peter Chien on 10/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <WatchKit/WatchKit.h>

@class Mixpanel;

@interface ExtensionDelegate : NSObject <WKExtensionDelegate>

@property (strong, nonatomic) Mixpanel *mixpanel;

@end
