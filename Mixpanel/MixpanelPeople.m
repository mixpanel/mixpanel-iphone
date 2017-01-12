//
//  MixpanelPeople.m
//  Mixpanel
//
//  Created by Sam Green on 6/16/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelPeople.h"
#import "MixpanelPeoplePrivate.h"
#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MPLogger.h"

#if defined(MIXPANEL_WATCH_EXTENSION)
#import "MixpanelWatchProperties.h"
#endif

@implementation MixpanelPeople

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel
{
    if (self = [self init]) {
        self.mixpanel = mixpanel;
        self.unidentifiedQueue = [NSMutableArray array];
        self.automaticPeopleProperties = [self collectAutomaticPeopleProperties];
    }
    return self;
}

- (NSString *)description
{
    __strong Mixpanel *strongMixpanel = self.mixpanel;
    return [NSString stringWithFormat:@"<MixpanelPeople: %p %@>", (void *)self, (strongMixpanel ? strongMixpanel.apiToken : @"")];
}

- (NSString *)deviceSystemVersion {
#if defined(MIXPANEL_WATCH_EXTENSION)
    return [MixpanelWatchProperties systemVersion];
#else
    return [UIDevice currentDevice].systemVersion;
#endif
}

- (NSDictionary *)collectAutomaticPeopleProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                             @"$ios_version": [self deviceSystemVersion],
                                                                             @"$ios_lib_version": [Mixpanel libVersion],
                                                                             }];
    NSDictionary *infoDictionary = [NSBundle mainBundle].infoDictionary;
    if (infoDictionary[@"CFBundleVersion"]) {
        p[@"$ios_app_version"] = infoDictionary[@"CFBundleVersion"];
    }
    if (infoDictionary[@"CFBundleShortVersionString"]) {
        p[@"$ios_app_release"] = infoDictionary[@"CFBundleShortVersionString"];
    }
    __strong Mixpanel *strongMixpanel = self.mixpanel;
    NSString *deviceModel = [strongMixpanel deviceModel];
    if (deviceModel) {
        p[@"$ios_device_model"] = deviceModel;
    }
    NSString *ifa = [strongMixpanel IFA];
    if (ifa) {
        p[@"$ios_ifa"] = ifa;
    }
    return [p copy];
}

- (void)addPeopleRecordToQueueWithAction:(NSString *)action andProperties:(NSDictionary *)properties
{
    NSNumber *epochMilliseconds = @(round([[NSDate date] timeIntervalSince1970] * 1000));
    __strong Mixpanel *strongMixpanel = self.mixpanel;
    if (strongMixpanel) {
        properties = [properties copy];
        BOOL ignore_time = self.ignoreTime;

        dispatch_async(strongMixpanel.serialQueue, ^{
            NSMutableDictionary *r = [NSMutableDictionary dictionary];
            NSMutableDictionary *p = [NSMutableDictionary dictionary];
            r[@"$token"] = strongMixpanel.apiToken;
            if (!r[@"$time"]) {
                // milliseconds unix timestamp
                r[@"$time"] = epochMilliseconds;
            }
            if (ignore_time) {
                r[@"$ignore_time"] = @YES;
            }

            if ([action isEqualToString:@"$unset"]) {
                // $unset takes an array of property names which is supplied to this method
                // in the properties parameter under the key "$properties"
                r[action] = properties[@"$properties"];
            } else {
                if ([action isEqualToString:@"$set"] || [action isEqualToString:@"$set_once"]) {
                    [p addEntriesFromDictionary:self.automaticPeopleProperties];
                }
                [p addEntriesFromDictionary:properties];
                r[action] = [NSDictionary dictionaryWithDictionary:p];
            }

            if (self.distinctId) {
                r[@"$distinct_id"] = self.distinctId;
                MPLogInfo(@"%@ queueing people record: %@", self.mixpanel, r);
                @synchronized (strongMixpanel) {
                    [strongMixpanel.peopleQueue addObject:r];
                    if (strongMixpanel.peopleQueue.count > 500) {
                        [strongMixpanel.peopleQueue removeObjectAtIndex:0];
                    }
                }
            } else {
                MPLogInfo(@"%@ queueing unidentified people record: %@", self.mixpanel, r);
                [self.unidentifiedQueue addObject:r];
                if (self.unidentifiedQueue.count > 500) {
                    [self.unidentifiedQueue removeObjectAtIndex:0];
                }
            }

            [strongMixpanel archivePeople];
        });
#if MIXPANEL_FLUSH_IMMEDIATELY
        [strongMixpanel flush];
#endif
    }
}

+ (NSString *)pushDeviceTokenToString:(NSData *)deviceToken
{
    const unsigned char *buffer = (const unsigned char *)deviceToken.bytes;
    if (!buffer) {
        return nil;
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    return [hex copy];
}

#pragma mark - Public API

- (void)addPushDeviceToken:(NSData *)deviceToken
{
    NSDictionary *properties = @{@"$ios_devices": @[[MixpanelPeople pushDeviceTokenToString:deviceToken]]};
    [self addPeopleRecordToQueueWithAction:@"$union" andProperties:properties];
}

- (void)removeAllPushDeviceTokens
{
    NSDictionary *properties = @{ @"$properties": @[@"$ios_devices"] };
    [self addPeopleRecordToQueueWithAction:@"$unset" andProperties:properties];
}

- (void)removePushDeviceToken:(NSData *)deviceToken
{
    NSDictionary *properties = @{@"$ios_devices": [MixpanelPeople pushDeviceTokenToString:deviceToken]};
    [self addPeopleRecordToQueueWithAction:@"$remove" andProperties:properties];
}

- (void)set:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$set" andProperties:properties];
}

- (void)set:(NSString *)property to:(id)object
{
    NSAssert(property != nil, @"property must not be nil");
    NSAssert(object != nil, @"object must not be nil");
    if (property == nil || object == nil) {
        return;
    }
    [self set:@{property: object}];
}

- (void)setOnce:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$set_once" andProperties:properties];
}

- (void)unset:(NSArray *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    for (id __unused v in properties) {
        NSAssert([v isKindOfClass:[NSString class]],
                 @"%@ unset property names should be NSString. found: %@", self, v);
    }
    // $unset takes an array but addPeopleRecordToQueueWithAction:andProperties takes an NSDictionary
    // so the array is stored under the key "$properties" which the above method expects when action is $unset
    [self addPeopleRecordToQueueWithAction:@"$unset" andProperties:@{@"$properties": properties}];
}

- (void)increment:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    for (id __unused v in properties.allValues) {
        NSAssert([v isKindOfClass:[NSNumber class]],
                 @"%@ increment property values should be NSNumber. found: %@", self, v);
    }
    [self addPeopleRecordToQueueWithAction:@"$add" andProperties:properties];
}

- (void)increment:(NSString *)property by:(NSNumber *)amount
{
    NSAssert(property != nil, @"property must not be nil");
    NSAssert(amount != nil, @"amount must not be nil");
    if (property == nil || amount == nil) {
        return;
    }
    [self increment:@{property: amount}];
}

- (void)append:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$append" andProperties:properties];
}

- (void)union:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    for (id __unused v in properties.allValues) {
        NSAssert([v isKindOfClass:[NSArray class]],
                 @"%@ union property values should be NSArray. found: %@", self, v);
    }
    [self addPeopleRecordToQueueWithAction:@"$union" andProperties:properties];
}

- (void)remove:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$remove" andProperties:properties];
}

- (void)merge:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [self addPeopleRecordToQueueWithAction:@"$merge" andProperties:properties];
}

- (void)trackCharge:(NSNumber *)amount
{
    [self trackCharge:amount withProperties:nil];
}

- (void)trackCharge:(NSNumber *)amount withProperties:(NSDictionary *)properties
{
    NSAssert(amount != nil, @"amount must not be nil");
    if (amount != nil) {
        NSMutableDictionary *txn = [NSMutableDictionary dictionaryWithObjectsAndKeys:amount, @"$amount", [NSDate date], @"$time", nil];
        if (properties) {
            [txn addEntriesFromDictionary:properties];
        }
        [self append:@{@"$transactions": txn}];
    }
}

- (void)clearCharges
{
    [self set:@{@"$transactions": @[]}];
}

- (void)deleteUser
{
    [self addPeopleRecordToQueueWithAction:@"$delete" andProperties:@{}];
}

@end
