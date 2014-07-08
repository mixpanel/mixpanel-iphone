//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPValueTransformers.h"


@implementation MPCGRectToNSDictionaryValueTransformer

+ (Class)transformedValueClass
{
    return [NSDictionary class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    if ([value respondsToSelector:@selector(CGRectValue)])
    {
        return CFBridgingRelease(CGRectCreateDictionaryRepresentation([value CGRectValue]));
    }

    return nil;
}

- (id)reverseTransformedValue:(id)value
{
    CGRect rect = CGRectZero;
    if ([value isKindOfClass:[NSDictionary class]] && CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)value, &rect))
    {
        return [NSValue valueWithCGRect:rect];
    }

    return [NSValue valueWithCGRect:CGRectZero];
}

@end
