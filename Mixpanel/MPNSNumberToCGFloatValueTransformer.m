//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPValueTransformers.h"


@implementation MPNSNumberToCGFloatValueTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *) value;
        
        // if the number is not a cgfloat, cast it to a cgfloat
        if (strcmp([number objCType], (char *) @encode(CGFloat)) != 0) {
            if (strcmp([number objCType], (char *) @encode(float)) == 0) {
                number = [NSNumber numberWithDouble:(CGFloat) [number floatValue]];
            } else if (strcmp([number objCType], (char *) @encode(double)) == 0) {
                number = [NSNumber numberWithFloat:(CGFloat) [number doubleValue]];
            }
            value = number;
        }
        
        return value;
    }
    
    return nil;
}

@end
