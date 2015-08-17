//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@class MPClassDescription;
@class MPObjectSerializerContext;
@class MPObjectSerializerConfig;
@class MPObjectIdentityProvider;

@interface MPObjectSerializer : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*!
 @param     An array of MPClassDescription instances.
 */
- (instancetype)initWithConfiguration:(MPObjectSerializerConfig *)configuration objectIdentityProvider:(MPObjectIdentityProvider *)objectIdentityProvider NS_DESIGNATED_INITIALIZER;

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject;

@end
