//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <UIKit/UIKit.h>

@class MPObjectSerializerConfig;
@class MPObjectIdentityProvider;

@interface MPApplicationStateSerializer : NSObject

- (instancetype)initWithApplication:(UIApplication *)application configuration:(MPObjectSerializerConfig *)configuration objectIdentityProvider:(MPObjectIdentityProvider *)objectIdentityProvider NS_DESIGNATED_INITIALIZER;

- (UIImage *)screenshotImageForWindowAtIndex:(NSUInteger)index;

- (NSDictionary *)objectHierarchyForWindowAtIndex:(NSUInteger)index;

@end
