//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPUIImageToNSDictionaryValueTransformer.h"
#import "NSData+MPBase64.h"
#import "MPCGSizeToNSDictionaryValueTransformer.h"
#import "MPUIEdgeInsetsToNSDictionaryValueTransformer.h"
#import <ImageIO/ImageIO.h>

@implementation MPUIImageToNSDictionaryValueTransformer

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
    NSDictionary *transformedValue = nil;

    if ([value isKindOfClass:[UIImage class]])
    {
        UIImage *image = value;

        NSValueTransformer *sizeTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPCGSizeToNSDictionaryValueTransformer class])];
        NSValueTransformer *insetsTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPUIEdgeInsetsToNSDictionaryValueTransformer class])];

        NSValue *sizeValue = [NSValue valueWithCGSize:image.size];
        NSValue *capInsetsValue = [NSValue valueWithUIEdgeInsets:image.capInsets];
        NSValue *alignmentRectInsetsValue = [NSValue valueWithUIEdgeInsets:image.alignmentRectInsets];

        NSArray *images = image.images ?: @[ image ];

        NSMutableArray *imageDictionaries = [[NSMutableArray alloc] init];
        for (UIImage *animationFrame in images)
        {
            NSDictionary *imageDictionary = @{
                @"scale": @(image.scale),
                @"mime_type" : @"image/png",
                @"data": [UIImagePNGRepresentation(animationFrame) mp_base64EncodedString]
            };

            [imageDictionaries addObject:imageDictionary];
        }

        transformedValue = @{
           @"imageOrientation": @(image.imageOrientation),
           @"renderingMode": @(image.renderingMode),
           @"size": [sizeTransformer transformedValue:sizeValue],
           @"resizingMode": @(image.resizingMode),
           @"duration": @(image.duration),
           @"capInsets": [insetsTransformer transformedValue:capInsetsValue],
           @"alignmentRectInsets": [insetsTransformer transformedValue:alignmentRectInsetsValue],
           @"images": [imageDictionaries copy],
        };
    }

    return transformedValue;
}

- (id)reverseTransformedValue:(id)value
{
    if ([value isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dictionaryValue = value;

        NSValueTransformer *insetsTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPUIEdgeInsetsToNSDictionaryValueTransformer class])];

        NSArray *imagesDictionary = dictionaryValue[@"images"];
        UIEdgeInsets capInsets = [[insetsTransformer reverseTransformedValue:dictionaryValue[@"capInsets"]] UIEdgeInsetsValue];

        NSMutableArray *images = [[NSMutableArray alloc] init];
        for (NSDictionary *imageDictionary in imagesDictionary)
        {
            NSNumber *scale = imageDictionary[@"scale"];
            UIImage *image = [UIImage imageWithData:[NSData mp_dataFromBase64String:imageDictionary[@"data"]] scale:fminf(1.0, [scale floatValue])];
            if (image)
            {
                [images addObject:image];
            }
        }

        UIImage *image = nil;

        if ([images count] > 1)
        {
            // animated image
            image =  [UIImage animatedImageWithImages:images duration:[dictionaryValue[@"duration"] doubleValue]];
        }
        else if ([images count] > 0)
        {
            image = [images objectAtIndex:0];
        }

        if (UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero) == NO)
        {
            if (dictionaryValue[@"resizingMode"])
            {
                UIImageResizingMode resizingMode = (UIImageResizingMode)[dictionaryValue[@"resizingMode"] integerValue];
                image = [image resizableImageWithCapInsets:capInsets resizingMode:resizingMode];
            }
            else
            {
                image = [image resizableImageWithCapInsets:capInsets];
            }
        }

        return image;
    }

    return nil;
}

@end
