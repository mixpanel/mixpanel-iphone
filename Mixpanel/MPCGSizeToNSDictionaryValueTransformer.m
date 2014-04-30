//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPCGSizeToNSDictionaryValueTransformer.h"

@implementation MPCGSizeToNSDictionaryValueTransformer

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
    if ([value respondsToSelector:@selector(CGSizeValue)])
    {
        return CFBridgingRelease(CGSizeCreateDictionaryRepresentation([value CGSizeValue]));
    }

    return nil;
}

- (id)reverseTransformedValue:(id)value
{
    CGSize size = CGSizeZero;
    if ([value isKindOfClass:[NSDictionary class]] && CGSizeMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)value, &size))
    {
        return [NSValue valueWithCGSize:size];
    }

    return [NSValue valueWithCGSize:CGSizeZero];
}

@end
