//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPPassThroughValueTransformer.h"

@implementation MPPassThroughValueTransformer

+ (Class)transformedValueClass
{
    return [NSObject class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    if (value == nil)
    {
        return [NSNull null];
    }

    return value;
}

- (id)reverseTransformedValue:(id)value
{
    if ([[NSNull null] isEqual:value])
    {
        return nil;
    }

    return value;
}


@end
