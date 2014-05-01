//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoResponseMessage.h"

@implementation MPABTestDesignerDeviceInfoResponseMessage

+ (instancetype)message
{
    // TODO: provide a payload
    return [[self alloc] initWithType:@"device_info_response"];
}

@end
