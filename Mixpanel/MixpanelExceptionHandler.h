//
//  MixpanelExceptionHandler.h
//  HelloMixpanel
//
//  Created by Sam Green on 7/28/15.
//  Copyright (c) 2015 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Mixpanel;

@interface MixpanelExceptionHandler : NSObject

+ (instancetype)sharedHandler;
- (void)addMixpanelInstance:(Mixpanel *)instance;

@end
