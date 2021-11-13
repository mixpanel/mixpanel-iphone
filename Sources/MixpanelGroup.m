//
//  MixpanelGroup.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelGroup.h"
#import "MPLogger.h"
#import "Mixpanel.h"
#import "MixpanelGroupPrivate.h"
#import "MixpanelPrivate.h"

@implementation MixpanelGroup

- (instancetype)init:(Mixpanel *)mixpanel groupKey:(NSString *)groupKey groupID:(id<MixpanelType>)groupID
{
    if (self = [super init]) {
        self.mixpanel = mixpanel;
        self.groupKey = groupKey;
        self.groupID = groupID;
    }
    return self;
}

- (void)set:(NSDictionary *)properties
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addGroupRecordToQueueWithAction:@"$set" andProperties:properties];
}

- (void)setOnce:(NSDictionary *)properties
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addGroupRecordToQueueWithAction:@"$set_once" andProperties:properties];
}

- (void)unset:(NSString *)property
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    NSAssert(property != nil, @"property must not be nil");
    // $unset takes a string but addGroupRecordToQueueWithAction:andProperties
    // takes an NSDictionary so the array is stored under the key "$properties"
    // which the above method expects when action is $unset
    [self addGroupRecordToQueueWithAction:@"$unset" andProperties:@{@"$properties" : @[ property ]}];
}

- (void)union:(NSString *)property values:(NSArray<id<MixpanelType>> *)values
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    [self addGroupRecordToQueueWithAction:@"$union" andProperties:@{property : values}];
}

- (void)remove:(NSString *)property value:(id<MixpanelType>)value
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    NSAssert(property != nil, @"property must not be nil");
    [self addGroupRecordToQueueWithAction:@"$remove" andProperties:@{property : value}];
}

- (void)deleteGroup
{
    [self addGroupRecordToQueueWithAction:@"$delete" andProperties:nil];
    // remove cache entry
    NSString *key = [self.mixpanel keyForGroup:self.groupKey groupID:self.groupID];
    @synchronized(self.mixpanel.cachedGroups) {
        [self.mixpanel.cachedGroups removeObjectForKey:key];
    }
}

- (void)addGroupRecordToQueueWithAction:(NSString *)action andProperties:(NSDictionary *)properties
{
    if ([self.mixpanel hasOptedOutTracking]) {
        return;
    }
    
    NSNumber *epochMilliseconds = @(round([[NSDate date] timeIntervalSince1970] * 1000));
    __strong Mixpanel *strongMixpanel = self.mixpanel;
    
    if (strongMixpanel) {
        properties = [properties copy];
        dispatch_async(strongMixpanel.serialQueue, ^{
            NSMutableDictionary *req = [NSMutableDictionary dictionary];
            NSMutableDictionary *props = [NSMutableDictionary dictionary];
            req[@"$token"] = strongMixpanel.apiToken;
            if (!req[@"$time"]) {
                // milliseconds unix timestamp
                req[@"$time"] = epochMilliseconds;
            }
            req[@"$group_key"] = self.groupKey;
            req[@"$group_id"] = self.groupID;
            req[@"$token"] = strongMixpanel.apiToken;
            if ([action isEqualToString:@"$unset"]) {
                // $unset takes an array of property names which is supplied to
                // this method in the properties parameter under the key
                // "$properties"
                req[action] = properties[@"$properties"];
            }
            else if ([action isEqualToString:@"delete"]) {
                req[action] = @"";
            }
            else {
                [props addEntriesFromDictionary:properties];
                NSDictionary *dict = [NSDictionary dictionaryWithDictionary:props];
                req[action] = dict;
            }
            
            MPLogInfo(@"%@ queueing group record: %@", strongMixpanel, req);
            [strongMixpanel.persistence saveEntity:req type:PersistenceTypeGroups];
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

@end
