//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@class MPClassDescription;
@class MPObjectSerializerContext;

@interface MPObjectSerializer : NSObject

/*!
 @param     An array of MPClassDescription instances.
 */
- (id)initWithClassDescriptions:(NSArray *)classDescriptions;

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject;

@end
