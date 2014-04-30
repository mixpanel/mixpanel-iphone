//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@interface MPApplicationStateSerializer : NSObject

- (id)initWithApplication:(UIApplication *)application;

- (UIImage *)screenshotImageForWindowAtIndex:(NSUInteger)index;

- (NSDictionary *)viewControllerHierarchyForWindowAtIndex:(NSUInteger)index;

@end
