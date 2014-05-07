//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoResponseMessage.h"

@implementation MPABTestDesignerDeviceInfoResponseMessage

+ (instancetype)message
{
    // TODO: provide a payload
    return [[self alloc] initWithType:@"device_info_response"];
}

- (NSString *)systemName
{
    return [self payloadObjectForKey:@"system_name"];
}

- (void)setSystemName:(NSString *)systemName
{
    [self setPayloadObject:systemName forKey:@"system_name"];
}

- (NSString *)systemVersion
{
    return [self payloadObjectForKey:@"system_version"];
}

- (void)setSystemVersion:(NSString *)systemVersion
{
    [self setPayloadObject:systemVersion forKey:@"system_version"];
}

- (NSString *)deviceName
{
    return [self payloadObjectForKey:@"device_name"];
}

- (void)setDeviceName:(NSString *)deviceName
{
    [self setPayloadObject:deviceName forKey:@"device_name"];
}

- (NSString *)deviceModel
{
    return [self payloadObjectForKey:@"device_model"];
}

- (void)setDeviceModel:(NSString *)deviceModel
{
    [self setPayloadObject:deviceModel forKey:@"device_model"];
}

- (NSString *)mainBundleIdentifier
{
    return [self payloadObjectForKey:@"main_bundle_identifier"];
}

- (void)setMainBundleIdentifier:(NSString *)mainBundleIdentifier
{
    [self setPayloadObject:mainBundleIdentifier forKey:@"main_bundle_identifier"];
}

@end
