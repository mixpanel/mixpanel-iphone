//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoRequestMessage.h"
#import "MPABTestDesignerDeviceInfoResponseMessage.h"
#import "MPABTestDesignerConnection.h"

NSString *const MPABTestDesignerDeviceInfoRequestMessageType = @"device_info_request";

@implementation MPABTestDesignerDeviceInfoRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:MPABTestDesignerDeviceInfoRequestMessageType];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MPABTestDesignerConnection *conn = weak_connection;

        MPABTestDesignerDeviceInfoResponseMessage *deviceInfoResponseMessage = [MPABTestDesignerDeviceInfoResponseMessage message];

        dispatch_sync(dispatch_get_main_queue(), ^{
            UIDevice *currentDevice = [UIDevice currentDevice];

            deviceInfoResponseMessage.systemName = currentDevice.systemName;
            deviceInfoResponseMessage.systemVersion = currentDevice.systemVersion;
            deviceInfoResponseMessage.deviceName = currentDevice.name;
            deviceInfoResponseMessage.deviceModel = currentDevice.model;
            deviceInfoResponseMessage.mainBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

        });

        [conn sendMessage:deviceInfoResponseMessage];
    }];

    return operation;
}

@end
