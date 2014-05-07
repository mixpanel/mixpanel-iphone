//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPCGImageRefToNSDictionaryValueTransformer.h"
#import "NSData+MPBase64.h"
#import <ImageIO/ImageIO.h>

@implementation MPCGImageRefToNSDictionaryValueTransformer

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
    
    if (value && CFGetTypeID((__bridge CFTypeRef)value) == CGImageGetTypeID())
    {
        CGImageRef image = (__bridge CGImageRef)value;

        NSMutableData *mutableData = [[NSMutableData alloc] init];
        NSDictionary *properties = @{(__bridge NSString *)kCGImageDestinationBackgroundColor : (__bridge id)[UIColor clearColor].CGColor};
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)mutableData, CFSTR("public.png"), 1, NULL);
        CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
        if (CGImageDestinationFinalize(destination))
        {
            CGSize size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
            NSDictionary *sizeDictionary = CFBridgingRelease(CGSizeCreateDictionaryRepresentation(size));
            transformedValue = @{
                @"size" : sizeDictionary,
                @"mime_type" : @"image/png",
                @"data" : [mutableData mp_base64EncodedString]
            };

        }
        CFRelease(destination);
    }

    return transformedValue;
}

- (id)reverseTransformedValue:(id)value
{
    if ([value isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dictionaryValue = value;

        NSDictionary *sizeDictionary = dictionaryValue[@"size"];
        NSString *mimeType = dictionaryValue[@"mime_type"];
        NSString *base64Data = dictionaryValue[@"data"];

        if (sizeDictionary && mimeType && base64Data)
        {
            NS_VALID_UNTIL_END_OF_SCOPE NSData *data = [NSData mp_dataFromBase64String:base64Data];

            CGSize size = CGSizeZero;
            if (CGSizeMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)sizeDictionary, &size))
            {
                CGImageRef image = NULL;
                CGDataProviderRef dataProvider = CGDataProviderCreateWithData (
                        NULL,
                        [data bytes],
                        [data length],
                        NULL
                );

                if ([mimeType isEqualToString:@"image/jpeg"])
                {
                    image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
                }
                else if([mimeType isEqualToString:@"image/png"])
                {
                    image = CGImageCreateWithPNGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
                }

                CFRelease(dataProvider);
                return CFBridgingRelease(image);
            }
        }
    }

    return nil;
}

@end
