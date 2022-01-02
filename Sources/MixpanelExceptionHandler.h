//
//  MixpanelExceptionHandler.h
//  HelloMixpanel
//
//  Copyright (c) Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Mixpanel;

@interface MixpanelExceptionHandler : NSObject

+ (instancetype)sharedHandler;
- (void)addMixpanelInstance:(Mixpanel *)instance;
@end
