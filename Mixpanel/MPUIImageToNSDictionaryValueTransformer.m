//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <ImageIO/ImageIO.h>
#import "MPValueTransformers.h"

@implementation MPUIImageToNSDictionaryValueTransformer

static NSMutableDictionary *imageCache;

+ (void)load {
    imageCache = [NSMutableDictionary dictionary];
}

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

    if ([value isKindOfClass:[UIImage class]]) {
        UIImage *image = value;

        NSValueTransformer *sizeTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPCGSizeToNSDictionaryValueTransformer class])];
        NSValueTransformer *insetsTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPUIEdgeInsetsToNSDictionaryValueTransformer class])];

        NSValue *sizeValue = [NSValue valueWithCGSize:image.size];
        NSValue *capInsetsValue = [NSValue valueWithUIEdgeInsets:image.capInsets];
        NSValue *alignmentRectInsetsValue = [NSValue valueWithUIEdgeInsets:image.alignmentRectInsets];

        NSArray *images = image.images ?: @[ image ];

        NSMutableArray *imageDictionaries = [NSMutableArray array];
        for (UIImage *frame in images) {
            NSData *imageData = UIImagePNGRepresentation(frame);
            NSString *imageDataString = [imageData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
            NSDictionary *imageDictionary = @{ @"scale": @(image.scale),
                                               @"mime_type": @"image/png",
                                               @"data": (imageData != nil ? imageDataString : [NSNull null]) };

            [imageDictionaries addObject:imageDictionary];
        }

        transformedValue = @{
           @"imageOrientation": @(image.imageOrientation),
           @"size": [sizeTransformer transformedValue:sizeValue],
           @"renderingMode": @(image.renderingMode),
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
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionaryValue = value;

        NSValueTransformer *insetsTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([MPUIEdgeInsetsToNSDictionaryValueTransformer class])];

        NSArray *imagesDictionary = dictionaryValue[@"images"];
        UIEdgeInsets capInsets = [[insetsTransformer reverseTransformedValue:dictionaryValue[@"capInsets"]] UIEdgeInsetsValue];

        NSMutableArray *images = [NSMutableArray array];
        for (NSDictionary *imageDictionary in imagesDictionary) {
            NSNumber *scale = imageDictionary[@"scale"];
            UIImage *image;
            if (imageDictionary[@"url"]) {
                @synchronized(imageCache) {
                    image = [imageCache valueForKey:imageDictionary[@"url"]];
                }
                if (!image) {
                    NSURL *imageUrl = [NSURL URLWithString: imageDictionary[@"url"]];
                    NSError *error;
                    NSData *imageData = [NSData dataWithContentsOfURL:imageUrl options:(NSDataReadingOptions)0 error:&error];
                    if (!error) {
                        image = [UIImage imageWithData:imageData scale:fminf(1.0, scale.floatValue)];
                        @synchronized(imageCache) {
                            if (image) {
                                imageCache[imageDictionary[@"url"]] = image;
                            }
                        }
                    }
                }
                if (image && imageDictionary[@"dimensions"]) {
                    NSDictionary *dimensions = imageDictionary[@"dimensions"];
                    CGSize size = CGSizeMake([dimensions[@"Width"] floatValue], [dimensions[@"Height"] floatValue]);
                    UIGraphicsBeginImageContext(size);
                    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
                    image = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
            }
            else if (imageDictionary[@"data"] && imageDictionary[@"data"] != [NSNull null]) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:imageDictionary[@"data"]
                                                                        options:NSDataBase64DecodingIgnoreUnknownCharacters];
                image = [UIImage imageWithData:imageData scale:fminf(1.0, scale.floatValue)];
            }

            if (image) {
                [images addObject:image];
            }
        }

        UIImage *image = nil;

        if (images.count > 1) {
            // animated image
            image =  [UIImage animatedImageWithImages:images duration:[dictionaryValue[@"duration"] doubleValue]];
        }
        else if (images.count > 0)
        {
            image = images[0];
        }

        if (image && UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero) == NO) {
            if (dictionaryValue[@"resizingMode"]) {
                UIImageResizingMode resizingMode = (UIImageResizingMode)[dictionaryValue[@"resizingMode"] integerValue];
                image = [image resizableImageWithCapInsets:capInsets resizingMode:resizingMode];
            } else {
                image = [image resizableImageWithCapInsets:capInsets];
            }
        }

        return image;
    }

    return nil;
}

@end
