//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "NSData+MPBase64.h"


@implementation MPABTestDesignerSnapshotResponseMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"snapshot_response"];
}

- (void)setScreenshot:(UIImage *)screenshot
{
    id payloadObject = nil;
    if (screenshot)
    {
        NSData *jpegSnapshotImageData = UIImageJPEGRepresentation(screenshot, 0.5);
        if (jpegSnapshotImageData)
        {
            payloadObject = [jpegSnapshotImageData mp_base64EncodedString];
        }
    }

    [self setPayloadObject:(payloadObject ?: [NSNull null]) forKey:@"screenshot"];
}

- (UIImage *)screenshot
{
    NSString *base64Image = [self payloadObjectForKey:@"screenshot"];
    NSData *imageData = [NSData mp_dataFromBase64String:base64Image];

    return imageData ? [UIImage imageWithData:imageData] : nil;
}

- (void)setSerializedObjects:(NSDictionary *)serializedObjects
{
    [self setPayloadObject:serializedObjects forKey:@"serialized_objects"];
}

- (NSDictionary *)serializedObjects
{
    return [self payloadObjectForKey:@"serialized_objects"];
}

@end
