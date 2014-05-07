//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoRequestMessage.h"
#import "MPABTestDesignerDeviceInfoResponseMessage.h"
#import "MPABTestDesignerConnection.h"

// Facebook Tweaks
#import "FBTweakStore.h"
#import "FBTweakCollection.h"
#import "FBTweakCategory.h"
#import "FBTweak.h"

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
            deviceInfoResponseMessage.tweaks = [self getFacebookTweaks];
        });

        [conn sendMessage:deviceInfoResponseMessage];
    }];

    return operation;
}

- (NSArray *) getFacebookTweaks
{
    NSMutableArray *tweaks = [NSMutableArray array];
    NSArray *categories = [FBTweakStore sharedInstance].tweakCategories;
    for (FBTweakCategory *tcat in categories) {
        for (FBTweakCollection *tcol in tcat.tweakCollections) {
            for (FBTweak *t in tcol.tweaks) {
                [tweaks addObject:@{@"category": tcat.name,
                                    @"collection": tcol.name,
                                    @"tweak": t.name,
                                    @"identifier": t.identifier,
                                    @"default": t.defaultValue ?: [NSNull null],
                                    @"minimum": t.minimumValue ?: [NSNull null],
                                    @"maximum": t.maximumValue ?: [NSNull null],
                                    }];
            }
        }
    }
    return [tweaks copy];
}

@end
