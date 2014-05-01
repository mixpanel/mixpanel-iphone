//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoMessage.h"

@implementation MPABTestDesignerDeviceInfoMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"device_info"];
}

- (NSDictionary *)payload
{
    return @{
            @"os" : @"todo"
    };
}

@end
