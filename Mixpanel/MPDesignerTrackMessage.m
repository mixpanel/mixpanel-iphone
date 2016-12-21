//
//  MPDesignerTrackMessage.m
//  HelloMixpanel
//
//  Created by Amanda Canyon on 9/3/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPDesignerEventBindingMessage.h"

@implementation MPDesignerTrackMessage

{
    NSDictionary *_payload;
}

+ (instancetype)message
{
    return [(MPDesignerTrackMessage *)[self alloc] initWithType:@"track_message"];
}

+ (instancetype)messageWithPayload:(NSDictionary *)payload
{
    return [(MPDesignerTrackMessage *)[self alloc] initWithType:@"track_message" andPayload:payload];
}

- (instancetype)initWithType:(NSString *)type
{
    return [self initWithType:type andPayload:@{}];
}

- (instancetype)initWithType:(NSString *)type andPayload:(NSDictionary *)payload
{
    if (self = [super initWithType:type]) {
        _payload = payload;
    }
    return self;
}

- (NSData *)JSONData
{
    NSDictionary *jsonObject = @{ @"type": self.type, @"payload": [_payload copy] };

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:(NSJSONWritingOptions)0 error:&error];
    if (error) {
        NSLog(@"Failed to serialize test designer message: %@", error);
    }

    return jsonData;
}

@end
