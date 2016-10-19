//
//  MixpanelWatchProperties.h
//  Mixpanel
//
//  Created by Peter Chien on 10/14/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MixpanelWatchProperties : NSObject

+ (NSDictionary *)collectDeviceProperties;
+ (NSString *)systemVersion;

@end
