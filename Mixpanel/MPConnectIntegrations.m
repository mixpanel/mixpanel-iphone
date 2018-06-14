//
//  MPConnectIntegrations.m
//  Mixpanel
//
//  Created by Peter Chien on 10/9/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "MPConnectIntegrations.h"

static const NSInteger UA_MAX_RETRIES = 3;

@interface MPConnectIntegrations ()

@property (nonatomic, weak) Mixpanel *mixpanel;
@property (nonatomic, strong) NSString *savedUrbanAirshipChannelID;
@property (nonatomic, strong) NSString *savedBrazeUserID;
@property (nonatomic, strong) NSString *savedDeviceId;
@property (nonatomic, assign) NSInteger urbanAirshipRetries;

@end

@implementation MPConnectIntegrations

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel {
    if (self = [super init]) {
        _mixpanel = mixpanel;
    }
    return self;
}

- (void)reset {
    self.savedUrbanAirshipChannelID = nil;
    self.savedBrazeUserID = nil;
    self.savedDeviceId = nil;
    self.urbanAirshipRetries = 0;
}

- (void)setupIntegrations:(NSArray<NSString *> *)integrations {
    if ([integrations containsObject:@"urbanairship"]) {
        [self setUrbanAirshipPeopleProp];
    }
    if ([integrations containsObject:@"braze"]) {
        [self setBrazePeopleProp];
    }
}

- (void)setUrbanAirshipPeopleProp {
    Class urbanAirship = NSClassFromString(@"UAirship");
    if (urbanAirship) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *channelID = [[urbanAirship performSelector:NSSelectorFromString(@"push")] performSelector:NSSelectorFromString(@"channelID")];
#pragma clang diagnostic pop
        if (!channelID.length) {
            self.urbanAirshipRetries++;
            if (self.urbanAirshipRetries <= UA_MAX_RETRIES) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self setUrbanAirshipPeopleProp];
                });
            }
        } else {
            self.urbanAirshipRetries = 0;
            if (![channelID isEqualToString:self.savedUrbanAirshipChannelID]) {
                [self.mixpanel.people set:@"$ios_urban_airship_channel_id" to:channelID];
                self.savedUrbanAirshipChannelID = channelID;
            }
        }
    }
}

- (void)setBrazePeopleProp {
    Class brazeClass = NSClassFromString(@"Appboy");
    if (brazeClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *externalUserId = [[[brazeClass performSelector:NSSelectorFromString(@"sharedInstance")] performSelector:NSSelectorFromString(@"user")] performSelector:NSSelectorFromString(@"userID")];
        NSString *deviceId = [[brazeClass performSelector:NSSelectorFromString(@"sharedInstance")] performSelector:NSSelectorFromString(@"getDeviceId")];
#pragma clang diagnostic pop
        if (deviceId.length) {
            if (![deviceId isEqualToString:self.savedDeviceId]) {
                [self.mixpanel createAlias:deviceId forDistinctID:self.mixpanel.distinctId];
                [self.mixpanel.people set:@"$braze_device_id" to:deviceId];
                self.savedDeviceId = deviceId;
            }
        }
        
        if (externalUserId.length) {
            if (![externalUserId isEqualToString:self.savedBrazeUserID]) {
                [self.mixpanel createAlias:externalUserId forDistinctID:self.mixpanel.distinctId];
                [self.mixpanel.people set:@"$braze_external_id" to:externalUserId];
                self.savedBrazeUserID = externalUserId;
            }
        }
    }
}

@end
