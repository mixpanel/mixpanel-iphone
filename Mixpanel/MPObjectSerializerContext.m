//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPObjectSerializerContext.h"
#import "MPObjectIdentifierProvider.h"


@implementation MPObjectSerializerContext
{
    NSMutableSet *_visitedObjects;
    NSMutableSet *_unvisitedObjects;
    NSMutableDictionary *_propertiesOfVisitedObjects;
    id<MPObjectIdentifierProvider> _objectIdentifierProvider;
}

- (id)initWithRootObject:(id)object objectIdentifierProvider:(id<MPObjectIdentifierProvider>)identifierProvider
{
    self = [super init];
    if (self)
    {
        _objectIdentifierProvider = identifierProvider;
        _visitedObjects = [NSMutableSet set];
        _unvisitedObjects = [NSMutableSet setWithObject:object];
        _propertiesOfVisitedObjects = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (BOOL)hasUnvisitedObjects
{
    return [_unvisitedObjects count] > 0;
}

- (void)enqueueUnvisitedObject:(NSObject *)object
{
    NSParameterAssert(object != nil);

    [_unvisitedObjects addObject:object];
}

- (NSObject *)dequeueUnvisitedObject
{
    NSObject *object = [_unvisitedObjects anyObject];
    [_unvisitedObjects removeObject:object];

    return object;
}

- (BOOL)isVisitedObject:(NSObject *)object
{
    return object && [_visitedObjects containsObject:object];
}

- (void)addVisitedObject:(NSObject *)object propertyValues:(NSDictionary *)propertyValues
{
    NSString *identifierForObject = [_objectIdentifierProvider identifierForObject:object];
    _propertiesOfVisitedObjects[identifierForObject] = propertyValues;
    [_visitedObjects addObject:object];
}

- (NSArray *)propertiesOfVisitedObjects
{
    return [_propertiesOfVisitedObjects allValues];
}

@end
