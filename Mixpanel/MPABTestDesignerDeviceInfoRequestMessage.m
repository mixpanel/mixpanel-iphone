//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoRequestMessage.h"

NSString *const MPABTestDesignerDeviceInfoRequestMessageType = @"device_info_request";

@implementation MPABTestDesignerDeviceInfoRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:MPABTestDesignerDeviceInfoRequestMessageType];
}

@end
