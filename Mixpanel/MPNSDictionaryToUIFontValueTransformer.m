//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPNSDictionaryToUIFontValueTransformer.h"


@implementation MPNSDictionaryToUIFontValueTransformer

+ (Class)transformedValueClass
{
    return [UIFont class];
}

- (id)transformedValue:(id)value
{
    if ([value isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dictionary = value;
        NSString *fontName = dictionary[@"font_name"];
        CGFloat fontSize = [dictionary[@"font_size"] floatValue];

        if (fontName && fontSize > 0.0f)
        {
            return [UIFont fontWithName:fontName size:fontSize];
        }
    }

    return nil;
}

@end
