//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@interface MPApplicationStateSerializer : NSObject

- (id)initWithApplication:(UIApplication *)application classDescriptions:(NSArray *)classDescriptions;

- (UIImage *)screenshotImageForWindowAtIndex:(NSUInteger)index;

- (NSDictionary *)objectHierarchyForWindowAtIndex:(NSUInteger)index;

@end
