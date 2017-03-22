//
//  MPResources.h
//  Mixpanel
//
//  Created by Sam Green on 5/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Mixpanel.h"

@interface MPResources : NSObject

+ (NSBundle *)frameworkBundle;
+ (NSString *)notificationXibName;
+ (UIImage *)imageNamed:(NSString *)name;

@end
