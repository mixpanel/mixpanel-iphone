//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPObjectSerializer.h"
#import "MPClassDescription.h"
#import "MPPropertyDescription.h"
#import "MPObjectSerializerContext.h"
#import "MPObjectIdentifierProvider.h"
#import "MPSequenceGenerator.h"

@interface MPObjectSerializer () <MPObjectIdentifierProvider>
@end

@implementation MPObjectSerializer
{
    NSMutableDictionary *_classDescriptions;
    NSMapTable *_objectToIdentifierMap;
    MPSequenceGenerator *_sequenceGenerator;
}

- (id)initWithClassDescriptions:(NSArray *)classDescriptions
{
    self = [super init];
    if (self)
    {
        _sequenceGenerator = [[MPSequenceGenerator alloc] init];
        _objectToIdentifierMap = [NSMapTable weakToStrongObjectsMapTable];
        _classDescriptions = [[NSMutableDictionary alloc] init];

        for (MPClassDescription *classDescription in classDescriptions)
        {
            _classDescriptions[classDescription.name] = classDescription;
        }
    }

    return self;
}

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject
{
    NSParameterAssert(rootObject != nil);

    MPObjectSerializerContext *context = [[MPObjectSerializerContext alloc] initWithRootObject:rootObject objectIdentifierProvider:self];

    while ([context hasUnvisitedObjects])
    {
        [self visitObject:[context dequeueUnvisitedObject] withContext:context];
    }

    return @{
            @"objects" : [context propertiesOfVisitedObjects],
            @"rootObject": [self identifierForObject:rootObject]
    };
}

- (void)visitObject:(NSObject *)object withContext:(MPObjectSerializerContext *)context
{
    NSParameterAssert(object != nil);
    NSParameterAssert(context != nil);

    NSMutableDictionary *propertyValues = [[NSMutableDictionary alloc] init];

    MPClassDescription *classDescription = [self classDescriptionForObject:object];
    if (classDescription)
    {
        for (MPPropertyDescription *propertyDescription in [classDescription propertyDescriptions])
        {
            if ([propertyDescription shouldReadPropertyValueForObject:object])
            {
                id propertyValue = [self propertyValueForObject:object withPropertyDescription:propertyDescription context:context];
                propertyValues[propertyDescription.name] = propertyValue ?: [NSNull null];
            }
        }
    }

    NSDictionary *visitedObject = @{
        @"id": [self identifierForObject:object],
        @"class": [self classHierarchyArrayForObject:object],
        @"properties": propertyValues
    };

    [context addVisitedObject:object propertyValues:visitedObject];
}

- (NSArray *)classHierarchyArrayForObject:(NSObject *)object
{
    NSMutableArray *classHierarchy = [[NSMutableArray alloc] init];

    Class aClass = [object class];
    while (aClass)
    {
        [classHierarchy addObject:NSStringFromClass(aClass)];
        aClass = [aClass superclass];
    }

    return [classHierarchy copy];
}

- (id)propertyValueForObject:(NSObject *)object withPropertyDescription:(MPPropertyDescription *)propertyDescription context:(MPObjectSerializerContext *)context
{
    id propertyValue = [object valueForKey:propertyDescription.name];

    if (propertyValue != nil)
    {
        if ([context isVisitedObject:propertyValue])
        {
            return [self identifierForObject:propertyValue];
        }
        else if ([self isNestedObjectType:propertyDescription.type])
        {
            [context enqueueUnvisitedObject:propertyValue];
            return [self identifierForObject:propertyValue];
        }
        else if ([propertyValue isKindOfClass:[NSArray class]])
        {
            NSArray *propertyValueArray = propertyValue;
            NSMutableArray *arrayOfIdentifiers = [[NSMutableArray alloc] initWithCapacity:[propertyValueArray count]];
            for (id value in propertyValueArray)
            {
                [context enqueueUnvisitedObject:value];
                [arrayOfIdentifiers addObject:[self identifierForObject:value]];
            }
            propertyValue = [arrayOfIdentifiers copy];
        }
    }

    return [propertyDescription.valueTransformer transformedValue:propertyValue];
}

- (NSString *)identifierForObject:(id)object
{
    NSString *identifier = [_objectToIdentifierMap objectForKey:object];
    if (identifier == nil)
    {
        identifier = [NSString stringWithFormat:@"$%" PRIi32, [_sequenceGenerator nextValue]];
        [_objectToIdentifierMap setObject:identifier forKey:object];
    }

    return identifier;
}

- (BOOL)isNestedObjectType:(NSString *)typeName
{
    return _classDescriptions[typeName] != nil;
}

- (MPClassDescription *)classDescriptionForObject:(NSObject *)object
{
    NSParameterAssert(object != nil);

    Class aClass = [object class];
    while (aClass != nil)
    {
        MPClassDescription *classDescription = _classDescriptions[NSStringFromClass(aClass)];
        if (classDescription)
        {
            return classDescription;
        }

        aClass = [aClass superclass];
    }

    return nil;
}

@end
