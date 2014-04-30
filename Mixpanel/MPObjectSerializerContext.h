//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@protocol MPObjectIdentifierProvider;

@interface MPObjectSerializerContext : NSObject

- (id)initWithRootObject:(id)object objectIdentifierProvider:(id<MPObjectIdentifierProvider>)identifierProvider;

- (BOOL)hasUnvisitedObjects;

- (void)enqueueUnvisitedObject:(NSObject *)object;

- (NSObject *)dequeueUnvisitedObject;

- (void)addVisitedObject:(NSObject *)object propertyValues:(NSDictionary *)propertyValues;

- (BOOL)isVisitedObject:(NSObject *)object;

- (NSArray *)propertiesOfVisitedObjects;

@end
