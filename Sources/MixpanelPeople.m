//
//  MixpanelPeople.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelPeople.h"
#import "MixpanelPeoplePrivate.h"
#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MPLogger.h"

#if TARGET_OS_WATCH
#import "MixpanelWatchProperties.h"
#endif

@implementation MixpanelPeople

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel
{
    if (self = [self init]) {
        self.mixpanel = mixpanel;
        self.automaticPeopleProperties = [self collectAutomaticPeopleProperties];
    }
    return self;
}

- (NSString *)description
{
    __strong Mixpanel *strongMixpanel = self.mixpanel;
    return [NSString stringWithFormat:@"<MixpanelPeople: %p %@>", (void *)self, (strongMixpanel ? strongMixpanel.apiToken : @"")];
}

- (NSString *)deviceSystemVersion
{
#if TARGET_OS_WATCH
    return [MixpanelWatchProperties systemVersion];
#elif TARGET_OS_OSX
    return [NSProcessInfo processInfo].operatingSystemVersionString;
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

    return [p copy];
}

- (void)addPeopleRecordToQueueWithAction:(NSString *)action andProperties:(NSDictionary *)properties
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    
#if defined(DEBUG)
    if (![[[properties allKeys] firstObject] hasPrefix:@"$ae_"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MPDebugUsedPeopleKey];
    }
#endif
    
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

            [r addEntriesFromDictionary:[strongMixpanel.sessionMetadata toDictionaryForEvent:NO]];

            if (self.mixpanel.anonymousId) {
              r[@"$device_id"] = self.mixpanel.anonymousId;
            }
            if (self.mixpanel.userId) {
                r[@"$user_id"] = self.mixpanel.userId;
            }
            if (self.mixpanel.hadPersistedDistinctId) {
                r[@"$had_persisted_distinct_id"] = [NSNumber numberWithBool: self.mixpanel.hadPersistedDistinctId];
            }
            if (self.distinctId) {
                r[@"$distinct_id"] = self.distinctId;
                MPLogInfo(@"%@ queueing people record: %@", strongMixpanel, r);
                [strongMixpanel.persistence saveEntity:r type:PersistenceTypePeople flag:IdentifiedFlag];
            } else {
                MPLogInfo(@"%@ queueing unidentified people record: %@", strongMixpanel, r);
                [strongMixpanel.persistence saveEntity:r type:PersistenceTypePeople flag:UnIdentifiedFlag];
            }
        });
#if MIXPANEL_FLUSH_IMMEDIATELY
        [strongMixpanel flush];
#else
        if ([Mixpanel isAppExtension]) {
            [strongMixpanel flush];
        }
#endif
    }
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
