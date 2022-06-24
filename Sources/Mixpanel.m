#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#import <objc/runtime.h>
#import "Mixpanel.h"
#import "MixpanelPeople.h"
#import "MixpanelPeoplePrivate.h"
#import "MixpanelGroup.h"
#import "MixpanelGroupPrivate.h"
#import "MixpanelPrivate.h"
#import "MPFoundation.h"
#import "MPLogger.h"
#import "MPNetworkPrivate.h"
#import "MPJSONHander.h"
#import "MixpanelPersistence.h"
#import "MixpanelIdentity.h"


#if TARGET_OS_WATCH
#import "MixpanelWatchProperties.h"
#import <WatchKit/WatchKit.h>
#elif TARGET_OS_OSX
#import <IOKit/IOKitLib.h>
#endif

#if !__has_feature(objc_arc)
#error The Mixpanel library must be compiled with ARC enabled
#endif

#define VERSION @"4.2.0"


@implementation Mixpanel

static NSMutableDictionary *instances;
static NSString *defaultProjectToken;

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
static CTTelephonyNetworkInfo *telephonyInfo;
#endif

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackCrashes:(BOOL)trackCrashes
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackCrashes:trackCrashes optOutTrackingByDefault:NO useUniqueDistinctId:NO];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackCrashes:(BOOL)trackCrashes optOutTrackingByDefault:(BOOL)optOutTrackingByDefault useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    if (instances[apiToken]) {
        return instances[apiToken];
    }

#if defined(DEBUG)
    const NSUInteger flushInterval = 2;
#else
    const NSUInteger flushInterval = 60;
#endif

    return [[self alloc] initWithToken:apiToken flushInterval:flushInterval trackCrashes:trackCrashes optOutTrackingByDefault:optOutTrackingByDefault useUniqueDistinctId:useUniqueDistinctId];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackCrashes:YES];
}


+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken optOutTrackingByDefault:(BOOL)optOutTrackingByDefault
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackCrashes:YES optOutTrackingByDefault:optOutTrackingByDefault useUniqueDistinctId:NO];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackCrashes:YES optOutTrackingByDefault:NO useUniqueDistinctId:useUniqueDistinctId];
}

+ (nullable Mixpanel *)sharedInstance
{
    if (instances.count == 0) {
        MPLogWarning(@"sharedInstance called before creating a Mixpanel instance");
        return nil;
    }

    if (instances.count > 1) {
        MPLogWarning([NSString stringWithFormat:@"sharedInstance called with multiple mixpanel instances. Using (the first) token %@", defaultProjectToken]);
    }

    return instances[defaultProjectToken];
}

- (instancetype)init:(NSString *)apiToken
{
    if (self = [super init]) {
        self.cachedGroups = [NSMutableDictionary dictionary];
        self.timedEvents = [NSMutableDictionary dictionary];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instances = [NSMutableDictionary dictionary];
            defaultProjectToken = apiToken;
            #if !MIXPANEL_NO_REACHABILITY_SUPPORT
            telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
            #endif
        });
    }

    return self;
}

- (instancetype)initWithToken:(NSString *)apiToken
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
               optOutTrackingByDefault:(BOOL)optOutTrackingByDefault
          useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    if (apiToken.length == 0) {
        if (apiToken == nil) {
            apiToken = @"";
        }
        MPLogWarning(@"%@ empty api token", self);
    }
    if (self = [self init:apiToken]) {
        if (![Mixpanel isAppExtension]) {
#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
            if (trackCrashes) {
                // Install signal and exception handlers first
                [[MixpanelExceptionHandler sharedHandler] addMixpanelInstance:self];
            }
#endif
        }
        self.apiToken = apiToken;
        _flushInterval = flushInterval;
        self.persistence = [[MixpanelPersistence alloc] initWithToken: apiToken];
        [self.persistence migrate];
        self.useIPAddressForGeoLocation = YES;
        self.shouldManageNetworkActivityIndicator = YES;
        self.flushOnBackground = YES;

        self.serverURL = @"https://api.mixpanel.com";
        self.useUniqueDistinctId = useUniqueDistinctId;
        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSDictionary dictionary];
        self.automaticProperties = [self collectAutomaticProperties];

#if !TARGET_OS_WATCH && !TARGET_OS_OSX
        if (![Mixpanel isAppExtension]) {
            self.taskId = UIBackgroundTaskInvalid;
        }
#endif
        NSString *label = [NSString stringWithFormat:@"com.mixpanel.%@.%p", apiToken, (void *)self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        NSString *networkLabel = [label stringByAppendingString:@".network"];
        self.networkQueue = dispatch_queue_create([networkLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        self.sessionMetadata = [[SessionMetadata alloc] init];
        self.network = [[MPNetwork alloc] initWithServerURL:[NSURL URLWithString:self.serverURL] mixpanel:self];
        self.people = [[MixpanelPeople alloc] initWithMixpanel:self];
        [self setUpListeners];
        [self unarchive];

        // check whether we should opt out by default
        // note: we don't override opt out persistence here since opt-out default state is often
        // used as an initial state while GDPR information is being collected
        if (optOutTrackingByDefault && ([self hasOptedOutTracking] || self.optOutStatusNotSet)) {
            [self optOutTracking];
        }

        if (![Mixpanel isAppExtension]) {
#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
            self.automaticEvents = [[AutomaticEvents alloc] init];
            self.automaticEvents.delegate = self;
            [self.automaticEvents initializeEvents:self.people apiToken:apiToken];
#endif
        }
#if defined(DEBUG)
        [self didDebugInit:apiToken];
#endif
        instances[apiToken] = self;
    }
    return self;
}

- (instancetype)initWithToken:(NSString *)apiToken
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
          useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    return [self initWithToken:apiToken
                 flushInterval:flushInterval
                  trackCrashes:trackCrashes
                optOutTrackingByDefault:NO
           useUniqueDistinctId:useUniqueDistinctId];
}

- (instancetype)initWithToken:(NSString *)apiToken
             andFlushInterval:(NSUInteger)flushInterval
{
    return [self initWithToken:apiToken
                 flushInterval:flushInterval
                  trackCrashes:NO
           useUniqueDistinctId:NO];
}

- (void)didDebugInit:(NSString *)distinctId
{
    if (distinctId.length == 32) {
        NSInteger debugInitCount = [[NSUserDefaults standardUserDefaults] integerForKey:MPDebugInitCountKey] + 1;
        [self sendHttpEvent:@"SDK Debug Launch" apiToken:@"metrics-1" distinctId:distinctId properties:@{@"Debug Launch Count": @(debugInitCount)}];
        [self checkIfImplemented:distinctId debugInitCount: debugInitCount];
        [[NSUserDefaults standardUserDefaults] setInteger:debugInitCount forKey:MPDebugInitCountKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)checkIfImplemented:(NSString *)distinctId
            debugInitCount:(NSInteger)debugInitCount
{
    BOOL hasImplemented = [[NSUserDefaults standardUserDefaults] boolForKey:MPDebugImplementedKey];
    if (!hasImplemented) {
        NSInteger completed = 0;
        BOOL hasTracked = [[NSUserDefaults standardUserDefaults] boolForKey:MPDebugTrackedKey];
        completed += hasTracked;
        BOOL hasIdentified = [[NSUserDefaults standardUserDefaults] boolForKey:MPDebugIdentifiedKey];
        completed += hasIdentified;
        BOOL hasAliased = [[NSUserDefaults standardUserDefaults] boolForKey:MPDebugAliasedKey];
        completed += hasAliased;
        BOOL hasUsedPeople = [[NSUserDefaults standardUserDefaults] boolForKey:MPDebugUsedPeopleKey];
        completed += hasUsedPeople;
        if (completed >= 3) {
            [self sendHttpEvent:@"SDK Implemented" apiToken:@"metrics-1" distinctId:distinctId properties:@{@"Tracked": @(hasTracked), @"Identified": @(hasIdentified), @"Aliased": @(hasAliased), @"Used People": @(hasUsedPeople), @"Debug Launch Count": @(debugInitCount)}];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MPDebugImplementedKey];
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (![Mixpanel isAppExtension]) {
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
        if (_reachability != NULL) {
            if (!SCNetworkReachabilitySetCallback(_reachability, NULL, NULL)) {
                MPLogError(@"%@ error unsetting reachability callback", self);
            }
            if (!SCNetworkReachabilitySetDispatchQueue(_reachability, NULL)) {
                MPLogError(@"%@ error unsetting reachability dispatch queue", self);
            }
            CFRelease(_reachability);
            _reachability = NULL;
        }
#endif
    }
}

+ (BOOL)isAppExtension
{
#if TARGET_OS_IOS
    return [[NSBundle mainBundle].bundlePath hasSuffix:@".appex"];
#else
    return NO;
#endif
}

#if !MIXPANEL_NO_UIAPPLICATION_ACCESS
+ (UIApplication *)sharedUIApplication
{
    if ([[UIApplication class] respondsToSelector:@selector(sharedApplication)]) {
        return [[UIApplication class] performSelector:@selector(sharedApplication)];
    }
    return nil;
}
#endif

- (BOOL)shouldManageNetworkActivityIndicator
{
    return self.network.shouldManageNetworkActivityIndicator;
}

- (void)setShouldManageNetworkActivityIndicator:(BOOL)shouldManageNetworkActivityIndicator
{
    self.network.shouldManageNetworkActivityIndicator = shouldManageNetworkActivityIndicator;
}

- (BOOL)useIPAddressForGeoLocation
{
    return self.network.useIPAddressForGeoLocation;
}

- (void)setUseIPAddressForGeoLocation:(BOOL)useIPAddressForGeoLocation
{
    self.network.useIPAddressForGeoLocation = useIPAddressForGeoLocation;
}

- (void)setTrackAutomaticEventsEnabled:(BOOL)trackAutomaticEventsEnabled
{
    [MixpanelPersistence saveAutomaticEventsEnabledFlag:trackAutomaticEventsEnabled fromDecide:NO apiToken:self.apiToken];
    if (!trackAutomaticEventsEnabled) {
        dispatch_async(self.serialQueue, ^{
            [self.persistence removeAutomaticEvents];
        });
    }
}

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
- (UInt64)minimumSessionDuration
{
    return self.automaticEvents.minimumSessionDuration;
}

- (void)setMinimumSessionDuration:(UInt64)minimumSessionDuration
{
    self.automaticEvents.minimumSessionDuration = minimumSessionDuration;
}

- (UInt64)maximumSessionDuration
{
    return self.automaticEvents.maximumSessionDuration;
}

- (void)setMaximumSessionDuration:(UInt64)maximumSessionDuration
{
    self.automaticEvents.maximumSessionDuration = maximumSessionDuration;
}
#endif

#pragma mark - Tracking
+ (void)assertPropertyTypes:(NSDictionary *)properties
{
    [Mixpanel assertPropertyTypesInDictionary:properties depth:0];
}

+ (void)assertPropertyType:(id)propertyValue depth:(NSUInteger)depth
{
    // Note that @YES and @NO pass as instances of NSNumber class.
    NSAssert([propertyValue isKindOfClass:[NSString class]] ||
             [propertyValue isKindOfClass:[NSNumber class]] ||
             [propertyValue isKindOfClass:[NSNull class]] ||
             [propertyValue isKindOfClass:[NSArray class]] ||
             [propertyValue isKindOfClass:[NSDictionary class]] ||
             [propertyValue isKindOfClass:[NSDate class]] ||
             [propertyValue isKindOfClass:[NSURL class]],
             @"%@ property values must be NSString, NSNumber, NSNull, NSArray, NSDictionary, NSDate or NSURL. got: %@ %@", self, [propertyValue class], propertyValue);

#ifdef DEBUG
    if (depth == 3) {
        MPLogWarning(@"Your properties are overly nested, specifically 3 or more levels deep. \
                     Generally this is not recommended due to its complexity.");
    }
    if ([propertyValue isKindOfClass:[NSDictionary class]]) {
        [Mixpanel assertPropertyTypesInDictionary:propertyValue depth:depth+1];
    } else if ([propertyValue isKindOfClass:[NSArray class]]) {
        [Mixpanel assertPropertyTypesInArray:propertyValue depth:depth+1];
    }
#endif
}

+ (void)assertPropertyTypesInDictionary:(NSDictionary *)properties depth:(NSUInteger)depth
{
    if([properties count] > 1000) {
        MPLogWarning(@"You have an NSDictionary in your properties that is bigger than 1000 in size. \
                     Generally this is not recommended due to its size.");
    }
    for (id key in properties) {
        id value = properties[key];
        NSAssert([key isKindOfClass:[NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [key class], key);
        [Mixpanel assertPropertyType:value depth:depth];
    }
}

+ (void)assertPropertyTypesInArray:(NSArray *)arrayOfProperties depth:(NSUInteger)depth
{
    if([arrayOfProperties count] > 1000) {
        MPLogWarning(@"You have an NSArray in your properties that is bigger than 1000 in size. \
                     Generally this is not recommended due to its size.");
    }
    for (id value in arrayOfProperties) {
        [Mixpanel assertPropertyType:value depth:depth];
    }
}

- (NSString *)defaultDistinctId
{
    NSString *distinctId;
#if defined(MIXPANEL_UNIQUE_DISTINCT_ID)
    distinctId = [self uniqueIdentifierForDevice];
#else
    if (self.useUniqueDistinctId) {
        distinctId = [self uniqueIdentifierForDevice];
    } else {
        distinctId = [[NSUUID UUID] UUIDString];
    }
#endif
    if (!distinctId) {
        MPLogInfo(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
    }
    return distinctId;
}

- (MixpanelIdentity *)currentMixpanelIdentity
{
    return [[MixpanelIdentity alloc] initWithDistinctId:self.distinctId peopleDistinctId:self.people.distinctId
                                            anonymousId:self.anonymousId userId:self.userId alias:self.alias hadPersistedDistinctId:self.hadPersistedDistinctId];;
}

- (void)identify:(NSString *)distinctId
{
    [self identify:distinctId usePeople:YES];
}

- (void)identify:(NSString *)distinctId usePeople:(BOOL)usePeople
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    if (distinctId.length == 0) {
        MPLogWarning(@"%@ cannot identify blank distinct id: %@", self, distinctId);
        return;
    }
    
#if defined(DEBUG)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MPDebugIdentifiedKey];
#endif

    dispatch_async(self.serialQueue, ^{
        if(!self.anonymousId) {
            self.anonymousId = self.distinctId;
            self.hadPersistedDistinctId = YES;
        }
        // identify only changes the distinct id if it doesn't match the ID
        // if it's new, blow away the alias as well.
        if (![distinctId isEqualToString:self.distinctId]) {
            NSString *oldDistinctId = [self.distinctId copy];
            self.alias = nil;
            self.distinctId = distinctId;
            self.userId = distinctId;
            [self track:@"$identify" properties:@{@"$anon_distinct_id": oldDistinctId}];
        }
        if (usePeople) {
            self.people.distinctId = distinctId;
            [self.persistence identifyPeople];
        } else {
            self.people.distinctId = nil;
        }
        
        [MixpanelPersistence saveIdentity:[self currentMixpanelIdentity] apiToken:self.apiToken];
    });
#if MIXPANEL_FLUSH_IMMEDIATELY
    [self flush];
#else
    if ([Mixpanel isAppExtension]) {
        [self flush];
    }
#endif
}

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID
{
    [self createAlias:alias forDistinctID:distinctID usePeople:YES];
}

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID usePeople:(BOOL)usePeople
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    if (alias.length == 0) {
        MPLogError(@"%@ create alias called with empty alias: %@", self, alias);
        return;
    }
    if (distinctID.length == 0) {
        MPLogError(@"%@ create alias called with empty distinct id: %@", self, distinctID);
        return;
    }
    
#if defined(DEBUG)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MPDebugAliasedKey];
#endif
    
    if (![alias isEqualToString:distinctID]) {
        dispatch_async(self.serialQueue, ^{
            self.alias = alias;
            [MixpanelPersistence saveIdentity:[self currentMixpanelIdentity]  apiToken:self.apiToken];
        });
        [self track:@"$create_alias" properties:@{ @"distinct_id": distinctID, @"alias": alias }];
        [self identify:distinctID usePeople:usePeople];
        [self flush];
    } else {
        MPLogWarning(@"alias: %@ matches distinctID: %@ - skipping api call.", alias, distinctID);
    }
}

- (void)track:(NSString *)event
{
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    if (event.length == 0) {
        MPLogWarning(@"%@ mixpanel track called with empty event parameter. using 'mp_event'", self);
        event = @"mp_event";
    }
    
    if (![MixpanelPersistence loadAutomaticEventsEnabledFlagWithApiToken:self.apiToken] && [event hasPrefix:@"$ae_"]) {
        return;
    }
    
#if defined(DEBUG)
    if (![event hasPrefix:@"$"]) [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MPDebugTrackedKey];
#endif
    
    properties = [properties copy];
    [Mixpanel assertPropertyTypes:properties];

    NSTimeInterval epochInterval = [[NSDate date] timeIntervalSince1970];
    NSNumber *epochMilliseconds = @(round(epochInterval * 1000));
    dispatch_async(self.serialQueue, ^{
        NSNumber *eventStartTime = self.timedEvents[event];
        NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:self.automaticProperties];
        p[@"token"] = self.apiToken;
        p[@"time"] = epochMilliseconds;
        if (eventStartTime != nil) {
            [self.timedEvents removeObjectForKey:event];
            p[@"$duration"] = @([[NSString stringWithFormat:@"%.3f", epochInterval - [eventStartTime doubleValue]] floatValue]);
        }
        if (self.distinctId) {
            p[@"distinct_id"] = self.distinctId;
        }
        if (self.anonymousId) {
            p[@"$device_id"] = self.anonymousId;
        }
        if (self.userId) {
            p[@"$user_id"] = self.userId;
        }
        if (self.hadPersistedDistinctId) {
            p[@"$had_persisted_distinct_id"] = [NSNumber numberWithBool:self.hadPersistedDistinctId];
        }
        [p addEntriesFromDictionary:self.superProperties];
        if (properties) {
            [p addEntriesFromDictionary:properties];
        }

        NSMutableDictionary *e = [[NSMutableDictionary alloc] initWithDictionary:@{ @"event": event,
                                                                                    @"properties": [NSDictionary dictionaryWithDictionary:p]}];
        [e addEntriesFromDictionary:[self.sessionMetadata toDictionaryForEvent:YES]];
        MPLogInfo(@"%@ queueing event: %@", self, e);
        [self.persistence saveEntity:e type:PersistenceTypeEvents flag:NO];
        [MixpanelPersistence saveTimedEvents:self.timedEvents apiToken:self.apiToken];
    });
#if MIXPANEL_FLUSH_IMMEDIATELY
    [self flush];
#else
    if ([Mixpanel isAppExtension]) {
        [self flush];
    }
#endif
}

- (void)trackWithGroups:(NSString *)event
             properties:(NSDictionary *)properties
                 groups:(NSDictionary *)groups {
    if ([self hasOptedOutTracking]) {
        return;
    }
    if (properties == nil) {
        [self track:event properties:groups];
        return;
    }
    if (groups == nil) {
        [self track:event properties:properties];
        return;
    }
    NSMutableDictionary *mergedProps = [properties mutableCopy];
    [groups enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (value != nil)
            [mergedProps setObject:value forKey:key];
    }];
    [self track:event properties:mergedProps];
}

- (void)addGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    if ([self hasOptedOutTracking]) {
        return;
    }

    [self addValuesToGroupSuperProperty:groupKey groupID:groupID];
    [self.people union:@{groupKey : @[groupID]}];
}

- (void)addValuesToGroupSuperProperty:(NSString *)groupKey
                              groupID:(id<MixpanelType>)groupID {
    [self updateSuperPropertiesAsync:^NSDictionary *(NSDictionary *superProps) {
        NSMutableDictionary *mutableSuperProps = [superProps mutableCopy];
        NSMutableArray<id<MixpanelType>> *values =
        [NSMutableArray arrayWithArray:mutableSuperProps[groupKey]];
        BOOL exist = NO;
        for (NSUInteger i = 0; i < [values count]; ++i) {
            if ([values[i] equalToMixpanelType:groupID]) {
                exist = YES;
                break;
            }
        }
        if (!exist) {
            [values addObject:groupID];
        }
        mutableSuperProps[groupKey] = [values copy];
        return mutableSuperProps;
    }];
}

- (void)removeGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    if ([self hasOptedOutTracking]) {
        return;
    }
    [self updateSuperPropertiesAsync:^NSDictionary *(NSDictionary *superProps) {
        NSMutableDictionary *mutableSuperProps = [superProps mutableCopy];
        NSObject *oldValue = superProps[groupKey];
        if (oldValue == nil) {
            return superProps;
        }
        if (![oldValue isKindOfClass:[NSArray<MixpanelType> class]]) {
            [mutableSuperProps removeObjectForKey:groupKey];
            [self.people unset:@[groupKey]];
            return mutableSuperProps;
        }
        NSMutableArray *vals =
        [NSMutableArray arrayWithArray:mutableSuperProps[groupKey]];

        for (NSUInteger i = 0; i < [vals count]; ++i) {
            if ([vals[i] equalToMixpanelType:groupID]) {
                [vals removeObjectAtIndex:i];
                break;
            }
        }
        if (![vals count]) {
            [mutableSuperProps removeObjectForKey:groupKey];
        } else {
            mutableSuperProps[groupKey] = vals;
        }
        [self.people remove:@{groupKey : groupID}];
        return mutableSuperProps;
    }];
}

- (void)setGroup:(NSString *)groupKey
        groupIDs:(NSArray<id<MixpanelType>> *)groupIDs {
    if ([self hasOptedOutTracking]) {
        return;
    }
    NSDictionary *properties = @{groupKey : groupIDs};
    [self registerSuperProperties:properties];
    [self.people set:properties];
}

- (void)setGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    NSArray *groupIDs = @[ groupID ];
    [self setGroup:groupKey groupIDs:groupIDs];
}

- (NSString *)keyForGroup:(NSString *)groupKey
                  groupID:(id<MixpanelType>)groupID {
    return [NSString stringWithFormat:@"%@_%@", groupKey, groupID];
}

- (MixpanelGroup *)getGroup:(NSString *)groupKey
                    groupID:(id<MixpanelType>)groupID {
    NSString *mapKey = [self keyForGroup:groupKey groupID:groupID];
    @synchronized(self.cachedGroups) {
        MixpanelGroup *group = self.cachedGroups[mapKey];
        if (!group || group.groupKey != groupKey ||
            ![groupID equalToMixpanelType:group.groupID]) {
            group = [[MixpanelGroup alloc] init:self groupKey:groupKey groupID:groupID];
            // if key collision happens, the old entry will be evicted
            self.cachedGroups[mapKey] = group;
        }
        return group;
    }
}

typedef NSDictionary*(^PropertyUpdate)(NSDictionary*);

- (void)updateSuperPropertiesAsync:(PropertyUpdate) update{
    dispatch_async(self.serialQueue, ^{
        NSDictionary* newSuperProp = update(self.currentSuperProperties);
        [self setSuperProperties:newSuperProp];
        [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    });
}

- (void)registerSuperProperties:(NSDictionary *)properties
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    [Mixpanel assertPropertyTypes:properties];
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        [tmp addEntriesFromDictionary:properties];
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    });
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties
{
    [self registerSuperPropertiesOnce:properties defaultValue:nil];
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(id)defaultValue
{
    if ([self hasOptedOutTracking]) {
        return;
    }
    
    [Mixpanel assertPropertyTypes:properties];
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        for (NSString *key in properties) {
            id value = tmp[key];
            if (value == nil || [value isEqual:defaultValue]) {
                tmp[key] = properties[key];
            }
        }
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    });
}

- (void)unregisterSuperProperty:(NSString *)propertyName
{
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        tmp[propertyName] = nil;
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    });
}

- (void)clearSuperProperties
{
    dispatch_async(self.serialQueue, ^{
        self.superProperties = @{};
        [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    });
}

- (NSDictionary *)currentSuperProperties
{
    return [self.superProperties copy];
}

- (void)timeEvent:(NSString *)event
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    NSNumber *startTime = @([[NSDate date] timeIntervalSince1970]);

    if (event.length == 0) {
        MPLogError(@"Mixpanel cannot time an empty event");
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        self.timedEvents[event] = startTime;
        [MixpanelPersistence saveTimedEvents:self.timedEvents apiToken:self.apiToken];
    });
}

- (double)eventElapsedTime:(NSString *)event
{
    __block NSNumber *startTime;
    
    dispatch_sync(self.serialQueue, ^{
        startTime = self.timedEvents[event];
    });
    
    if (startTime == nil) {
        return 0;
    } else {
        return [[NSDate date] timeIntervalSince1970] - [startTime doubleValue];
    }
}

- (void)clearTimedEvent:(NSString *)event
{
    if (event.length == 0) {
        MPLogError(@"Mixpanel cannot clear the timer for an empty event");
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        [self.timedEvents removeObjectForKey:event];
        [MixpanelPersistence saveTimedEvents:self.timedEvents apiToken:self.apiToken];
    });
}

- (void)clearTimedEvents
{
    dispatch_async(self.serialQueue, ^{
        self.timedEvents = [NSMutableDictionary dictionary];
        [MixpanelPersistence saveTimedEvents:self.timedEvents apiToken:self.apiToken];
    });
}

- (void)reset
{
    [self flush];
    dispatch_async(self.serialQueue, ^{
        // wait for all current network requests to finish before resetting
        [MixpanelPersistence deleteMPUserDefaultsData:self.apiToken];
        self.anonymousId = [self defaultDistinctId];
        self.distinctId = self.anonymousId;
        self.superProperties = [NSDictionary dictionary];
        self.userId = nil;
        self.people.distinctId = nil;
        self.alias = nil;
        self.hadPersistedDistinctId = NO;
        self.cachedGroups = [NSMutableDictionary dictionary];
        self.timedEvents = [NSMutableDictionary dictionary];
        self.decideResponseCached = NO;
        [self.persistence resetEntities];
        [self archive];
    });
}


- (void)optOutTracking{
    if (self.people.distinctId) {
        [self.people deleteUser];
        [self.people clearCharges];
        [self flush];
    }
    dispatch_async(self.serialQueue, ^{
        self.alias = nil;
        self.people.distinctId = nil;
        self.userId = nil;
        self.anonymousId = [self defaultDistinctId];
        self.distinctId = self.anonymousId;
        self.hadPersistedDistinctId = NO;
        self.superProperties = [NSDictionary new];
        [self.timedEvents removeAllObjects];
        [self archive];
    });
    
    self.optOutStatus = YES;
    [MixpanelPersistence saveOptOutStatusFlag:YES apiToken:self.apiToken];
}

- (void)optInTracking
{
    [self optInTrackingForDistinctID:nil withEventProperties:nil];
}

- (void)optInTrackingForDistinctID:(NSString *)distinctID
{
    [self optInTrackingForDistinctID:distinctID withEventProperties:nil];
}

- (void)optInTrackingForDistinctID:(NSString *)distinctID withEventProperties:(NSDictionary *)properties
{
    self.optOutStatus = NO;
    [MixpanelPersistence saveOptOutStatusFlag:NO apiToken:self.apiToken];
    if (distinctID) {
        [self identify:distinctID];
    }
    [self track:@"$opt_in" properties:properties];
}

- (BOOL)hasOptedOutTracking
{
    return self.optOutStatus;
}

#pragma mark - Network control
- (void)setServerURL:(NSString *)serverURL
{
    _serverURL = serverURL.copy;
    self.network = [[MPNetwork alloc] initWithServerURL:[NSURL URLWithString:serverURL] mixpanel:self];
}

- (NSUInteger)flushInterval {
    return _flushInterval;
}

- (void)setFlushInterval:(NSUInteger)interval
{
    @synchronized (self) {
        _flushInterval = interval;
    }
    [self flush];
    [self startFlushTimer];
}

- (void)startFlushTimer
{
    [self stopFlushTimer];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.flushInterval > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            MPLogInfo(@"%@ started flush timer: %@", self, self.timer);
        }
    });
}

- (void)stopFlushTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
            MPLogInfo(@"%@ stopped flush timer: %@", self, self.timer);
            self.timer = nil;
        }
    });
}

- (void)flush
{
    [self flushWithCompletion:nil];
}

- (void)flushWithCompletion:(void (^)(void))handler
{
    if ([self hasOptedOutTracking]) {
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), handler);
        }
        return;
    }

    dispatch_async(self.serialQueue, ^{
        MPLogInfo(@"%@ flush starting", self);
        
        __strong id<MixpanelDelegate> strongDelegate = self.delegate;
        if (strongDelegate && [strongDelegate respondsToSelector:@selector(mixpanelWillFlush:)]) {
            if (![strongDelegate mixpanelWillFlush:self]) {
                MPLogInfo(@"%@ flush deferred by delegate", self);
                return;
            }
        }
        
        NSArray *eventQueue = [self.persistence loadEntitiesInBatch:PersistenceTypeEvents];
        NSArray *peopleQueue = [self.persistence loadEntitiesInBatch:PersistenceTypePeople];
        NSArray *groupsQueue = [self.persistence loadEntitiesInBatch:PersistenceTypeGroups];
        
        dispatch_async(self.networkQueue, ^{
            [self.network flushEventQueue:eventQueue];
            [self.network flushPeopleQueue:peopleQueue];
            [self.network flushGroupsQueue:groupsQueue];
            
            if (handler) {
                dispatch_async(dispatch_get_main_queue(), handler);
            }

            MPLogInfo(@"%@ flush complete", self);
        });
    });
}


#pragma mark - Persistence
- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
#if !TARGET_OS_TV
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
}

- (void)archive
{
    [MixpanelPersistence saveTimedEvents:self.timedEvents apiToken:self.apiToken];
    [MixpanelPersistence saveSuperProperties:self.superProperties apiToken:self.apiToken];
    [MixpanelPersistence saveIdentity:[self currentMixpanelIdentity] apiToken:self.apiToken];
}

- (void)unarchive
{
    self.optOutStatus = [MixpanelPersistence loadOptOutStatusFlagWithApiToken:self.apiToken];
    self.optOutStatusNotSet = [MixpanelPersistence optOutStatusNotSet:self.apiToken];
    self.superProperties = [MixpanelPersistence loadSuperProperties:self.apiToken];
    self.timedEvents = [[MixpanelPersistence loadTimedEvents:self.apiToken] mutableCopy];
    MixpanelIdentity *mixpanelIdentity = [MixpanelPersistence loadIdentity:self.apiToken];
    self.distinctId = mixpanelIdentity.distinctId;
    self.people.distinctId = mixpanelIdentity.peopleDistinctId;
    self.anonymousId = mixpanelIdentity.anonymousId;
    self.userId = mixpanelIdentity.userId;
    self.alias = mixpanelIdentity.alias;
    self.hadPersistedDistinctId = mixpanelIdentity.hadPersistedDistinctId;
    if (!self.distinctId) {
        self.distinctId = [self defaultDistinctId];
        self.anonymousId = self.distinctId;
        self.hadPersistedDistinctId = YES;
        self.userId = nil;
        [MixpanelPersistence saveIdentity:[self currentMixpanelIdentity] apiToken:self.apiToken];
    }
}

#pragma mark - Application Helpers

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Mixpanel: %p - Token: %@>", (void *)self, self.apiToken];
}

- (NSString *)deviceModel
{
    NSString *results = nil;
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char answer[size];
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    if (size) {
        results = @(answer);
    } else {
        MPLogError(@"Failed fetch hw.machine from sysctl.");
    }
    return results;
}

#if TARGET_OS_OSX
- (NSString *)macOSIdentifier
{
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    CFStringRef serialNumberAsCFString = NULL;
    if (platformExpert) {
        serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert,
                                                                 CFSTR(kIOPlatformSerialNumberKey),
                                                                 kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }
    NSString *serialNumberAsNSString = nil;
    if (serialNumberAsCFString) {
        serialNumberAsNSString = [NSString stringWithString:(__bridge NSString *)serialNumberAsCFString];
        CFRelease(serialNumberAsCFString);
    }
    return serialNumberAsNSString;
}
#endif


- (NSString *)uniqueIdentifierForDevice
{
    NSString *distinctId = nil;
#if !TARGET_OS_WATCH && !TARGET_OS_OSX
    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
#elif TARGET_OS_OSX
    distinctId = [self macOSIdentifier];
#endif
    return distinctId;
}

- (void)setCurrentRadio
{
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *properties = [self.automaticProperties mutableCopy];
        if (properties) {
            properties[@"$radio"] = [self currentRadio];
            self.automaticProperties = [properties copy];
        }
    });
}

- (NSString *)currentRadio
{
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
    if (![Mixpanel isAppExtension]) {
        if (@available(iOS 12, *)) {
            NSDictionary *radioDict = telephonyInfo.serviceCurrentRadioAccessTechnology;
            NSMutableString *radio = [NSMutableString new];
            [radioDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL * _Nonnull stop) {
                if (value && [value hasPrefix:@"CTRadioAccessTechnology"]) {
                    if (radio.length > 0) {
                        [radio appendString:@","];
                    }
                    [radio appendString:[value substringFromIndex:23]];
                }
            }];
            return radio.length == 0 ? @"None" : [radio copy];
        } else {
            NSString *radio = nil;
            if (@available(iOS 12, *)) {
                radio = [[telephonyInfo.serviceCurrentRadioAccessTechnology allValues] firstObject];
            } else {
                radio = telephonyInfo.currentRadioAccessTechnology;
            }
            if (!radio) {
                radio = @"None";
            } else if ([radio hasPrefix:@"CTRadioAccessTechnology"]) {
                radio = [radio substringFromIndex:23];
            }
            return radio;
        }
    }
#endif
    return @"";
}

- (NSString *)libVersion
{
    return [Mixpanel libVersion];
}

+ (NSString *)libVersion
{
    return VERSION;
}

- (NSDictionary *)collectDeviceProperties
{
#if TARGET_OS_WATCH
    return [MixpanelWatchProperties collectDeviceProperties];
#elif TARGET_OS_OSX
    CGSize size = [NSScreen mainScreen].frame.size;
    return @{
             @"$os": @"macOS",
             @"$os_version": [NSProcessInfo processInfo].operatingSystemVersionString,
             @"$screen_height": @((NSInteger)size.height),
             @"$screen_width": @((NSInteger)size.width),
             };
#else
    UIDevice *device = [UIDevice currentDevice];
    CGSize size = [UIScreen mainScreen].bounds.size;
    return @{
             @"$os": [device systemName],
             @"$os_version": [device systemVersion],
             @"$screen_height": @((NSInteger)size.height),
             @"$screen_width": @((NSInteger)size.width),
             };
#endif
}

- (NSDictionary *)collectAutomaticProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    id deviceModel = [self deviceModel] ? : [NSNull null];

    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_version"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_release"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_build_number"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_version_string"];

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
    if (![Mixpanel isAppExtension]) {
        CTCarrier *carrier = nil;
        if (@available(iOS 12, *)) {
            NSArray *carriers = [[telephonyInfo serviceSubscriberCellularProviders] allValues];
            // Find the first carrier object that has a non-empty name
            for (CTCarrier *carrierCandidate in carriers) {
                if (carrierCandidate.carrierName.length != 0) {
                    carrier = carrierCandidate;
                    break;
                }
            }
            // Use the first object as fallback in case there are no carriers with a name
            if (carrier == nil) {
                carrier = carriers.firstObject;
            }
        } else {
            carrier = [telephonyInfo subscriberCellularProvider];
        }
        [p setValue:carrier.carrierName forKey:@"$carrier"];
    }
#endif

    [p addEntriesFromDictionary:@{
                                  @"mp_lib": @"iphone",
                                  @"$lib_version": [self libVersion],
                                  @"$manufacturer": @"Apple",
                                  @"$model": deviceModel,
                                  @"mp_device_model": deviceModel, //legacy
                                  }];
    [p addEntriesFromDictionary:[self collectDeviceProperties]];
    return [p copy];
}

#pragma mark - UIApplication Events

#if !TARGET_OS_OSX
- (void)setUpListeners
{
    if (![Mixpanel isAppExtension]) {
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
        // wifi reachability
        if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "api.mixpanel.com")) != NULL) {
            SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
            if (SCNetworkReachabilitySetCallback(_reachability, MixpanelReachabilityCallback, &context)) {
                if (!SCNetworkReachabilitySetDispatchQueue(_reachability, self.serialQueue)) {
                    // cleanup callback if setting dispatch queue failed
                    SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
                }
            }
        }

        // cellular info
        [self setCurrentRadio];
        // Temporarily remove the ability to monitor the radio change due to a crash issue might relate to the api from Apple
        // https://openradar.appspot.com/46873673
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(setCurrentRadio)
//                                                     name:CTRadioAccessTechnologyDidChangeNotification
//                                                   object:nil];
#endif // MIXPANEL_NO_REACHABILITY_SUPPORT

#if !MIXPANEL_NO_APP_LIFECYCLE_SUPPORT
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        // Application lifecycle events
        [notificationCenter addObserver:self
                               selector:@selector(applicationWillResignActive:)
                                   name:UIApplicationWillResignActiveNotification
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(applicationDidBecomeActive:)
                                   name:UIApplicationDidBecomeActiveNotification
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(applicationDidEnterBackground:)
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(applicationWillEnterForeground:)
                                   name:UIApplicationWillEnterForegroundNotification
                                 object:nil];
#endif // MIXPANEL_NO_APP_LIFECYCLE_SUPPORT
    }
}
#else
- (void)setUpListeners
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    // Application lifecycle events
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:NSApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:NSApplicationDidBecomeActiveNotification
                             object:nil];
}
#endif


#if !MIXPANEL_NO_REACHABILITY_SUPPORT

static void MixpanelReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    Mixpanel *mixpanel = (__bridge Mixpanel *)info;
    if (mixpanel && [mixpanel isKindOfClass:[Mixpanel class]]) {
        [mixpanel reachabilityChanged:flags];
    }
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    // this should be run in the serial queue. the reason we don't dispatch_async here
    // is because it's only ever called by the reachability callback, which is already
    // set to run on the serial queue. see SCNetworkReachabilitySetDispatchQueue in init
    NSMutableDictionary *properties = [self.automaticProperties mutableCopy];
    if (properties) {
        BOOL wifi = (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsIsWWAN);
        properties[@"$wifi"] = @(wifi);
        self.automaticProperties = [properties copy];
        MPLogInfo(@"%@ reachability changed, wifi=%d", self, wifi);
    }
}

#endif // MIXPANEL_NO_REACHABILITY_SUPPORT

#if !MIXPANEL_NO_APP_LIFECYCLE_SUPPORT

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    MPLogInfo(@"%@ application did become active", self);
    [self startFlushTimer];
    
#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
    if (![Mixpanel isAppExtension]) {
        [self checkForDecideResponse];
    }
#endif
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    MPLogInfo(@"%@ application will resign active", self);
    [self stopFlushTimer];

#if TARGET_OS_OSX
    if (self.flushOnBackground) {
        [self flush];
    } else {
        dispatch_async(self.serialQueue, ^{
            [self archive];
        });
    }
#endif
}

#if !TARGET_OS_OSX
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    MPLogInfo(@"%@ did enter background", self);
    if ([self hasOptedOutTracking]) {
        return;
    }

    __block UIBackgroundTaskIdentifier backgroundTask = [[Mixpanel sharedUIApplication] beginBackgroundTaskWithExpirationHandler:^{
        MPLogInfo(@"%@ flush %lu cut short", self, (unsigned long) backgroundTask);
        [[Mixpanel sharedUIApplication] endBackgroundTask:backgroundTask];
        self.taskId = UIBackgroundTaskInvalid;
    }];
    self.taskId = backgroundTask;
    MPLogInfo(@"%@ starting background cleanup task %lu", self, (unsigned long)self.taskId);

    dispatch_group_t bgGroup = dispatch_group_create();
    NSString *trackedKey = [NSString stringWithFormat:@"MPTracked:%@", self.apiToken];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:trackedKey]) {
        dispatch_group_enter(bgGroup);
        [self sendHttpEvent:@"Integration"
                   apiToken:@"85053bf24bba75239b16a601d9387e17"
                 distinctId:self.apiToken
                 properties:@{}
               updatePeople:NO
          completionHandler:^(NSData *responseData,
                              NSURLResponse *urlResponse,
                              NSError *error) {
            if (!error) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:trackedKey];
            }
            dispatch_group_leave(bgGroup);
        }];
    }

    @synchronized (self) {
        self.decideResponseCached = NO;
    }
    if (self.flushOnBackground) {
        dispatch_group_enter(bgGroup);
        [self flushWithCompletion:^{
            dispatch_group_leave(bgGroup);
        }];
    }
    dispatch_group_notify(bgGroup, dispatch_get_main_queue(), ^{
        MPLogInfo(@"%@ ending background cleanup task %lu", self, (unsigned long)self.taskId);
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[Mixpanel sharedUIApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification
{
    MPLogInfo(@"%@ will enter foreground", self);
    dispatch_async(self.serialQueue, ^{
        [self.sessionMetadata reset];
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[Mixpanel sharedUIApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
            [self.network updateNetworkActivityIndicator:NO];
        }
    });
}

#endif // MIXPANEL_MACOS

#endif // MIXPANEL_NO_APP_LIFECYCLE_SUPPORT

- (void)sendHttpEvent:(NSString *)eventName
             apiToken:(NSString *)apiToken
           distinctId:(NSString *)distinctId
{
    [self sendHttpEvent:eventName apiToken:apiToken distinctId:distinctId properties:@{} updatePeople: YES completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {}];
}


- (void)sendHttpEvent:(NSString *)eventName
             apiToken:(NSString *)apiToken
           distinctId:(NSString *)distinctId
           properties:(NSDictionary *)properties
{
    [self sendHttpEvent:eventName apiToken:apiToken distinctId:distinctId properties:properties updatePeople: YES completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {}];
}

- (void)sendHttpEvent:(NSString *)eventName
             apiToken:(NSString *)apiToken
           distinctId:(NSString *)distinctId
           properties:(NSDictionary *)properties
         updatePeople:(BOOL)updatePeople
    completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler
{
    NSMutableDictionary *trackingProperties = [[NSMutableDictionary alloc] initWithDictionary:@{@"token": apiToken, @"mp_lib": @"iphone", @"distinct_id": distinctId, @"$lib_version": self.libVersion, @"Logging Enabled": @(self.enableLogging), @"Project Token": distinctId, @"DevX": @YES}];
    [trackingProperties addEntriesFromDictionary:properties];
    NSString *requestData = [MPJSONHandler encodedJSONString:@[@{@"event": eventName, @"properties": trackingProperties}]];
    NSURLQueryItem *useIPAddressForGeoLocation = [NSURLQueryItem queryItemWithName:@"ip" value:self.useIPAddressForGeoLocation ? @"1": @"0"];
    NSURLRequest *request = [self.network buildPostRequestForEndpoint:MPNetworkEndpointTrack withQueryItems:@[useIPAddressForGeoLocation] andBody:requestData];
    [[[MPNetwork sharedURLSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
    if (updatePeople) {
        NSString *engageData = [MPJSONHandler encodedJSONString:@[@{@"$token": apiToken, @"$distinct_id": distinctId, @"$add": @{eventName: @1}}]];
        NSURLRequest *engageRequest = [self.network buildPostRequestForEndpoint:MPNetworkEndpointEngage withQueryItems:@[useIPAddressForGeoLocation] andBody:engageData];
        [[[MPNetwork sharedURLSession] dataTaskWithRequest:engageRequest completionHandler:completionHandler] resume];
    }
}

#pragma mark - Logging
- (void)setEnableLogging:(BOOL)enableLogging
{
    [MPLogger sharedInstance].loggingEnabled = enableLogging;
#if defined(DEBUG)
    [self sendHttpEvent:@"Toggle SDK Logging" apiToken:@"metrics-1" distinctId:self.apiToken properties:@{@"Logging Enabled": @(enableLogging)}];
#endif
}

- (BOOL)enableLogging
{
    return [MPLogger sharedInstance].loggingEnabled;
}


#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT

#pragma mark - Decide

- (void)handlingAutomaticEventsWith:(BOOL)decideTrackAutomaticEvents {
    [MixpanelPersistence saveAutomaticEventsEnabledFlag:decideTrackAutomaticEvents fromDecide:YES apiToken:self.apiToken];
    if (!decideTrackAutomaticEvents) {
        dispatch_async(self.serialQueue, ^{
            [self.persistence removeAutomaticEvents];
        });
    }
}

- (void)checkForDecideResponse
{
    dispatch_async(self.networkQueue, ^{
        __block BOOL hadError = NO;

        BOOL decideResponseCached;
        @synchronized (self) {
            decideResponseCached = self.decideResponseCached;
        }

        if (!decideResponseCached) {
            // Build a proper URL from our parameters
            NSArray *queryItems = [MPNetwork buildDecideQueryForProperties:self.people.automaticPeopleProperties
                                                            withDistinctID:self.people.distinctId ?: self.distinctId
                                                                  andToken:self.apiToken];


            // Build a network request from the URL
            NSURLRequest *request = [self.network buildGetRequestForEndpoint:MPNetworkEndpointDecide
                                                              withQueryItems:queryItems];

            // Send the network request
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [[[MPNetwork sharedURLSession] dataTaskWithRequest:request completionHandler:^(NSData *responseData,
                                                                                           NSURLResponse *urlResponse,
                                 
                                                                                           NSError *error) {                
                if (error) {
                    MPLogError(@"%@ decide check http error: %@", self, error);
                    hadError = YES;
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                // Handle network response
                NSDictionary *object = [NSJSONSerialization JSONObjectWithData:responseData options:(NSJSONReadingOptions)0 error:&error];
                if (error) {
                    MPLogError(@"%@ decide check json error: %@, data: %@", self, error, [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                    hadError = YES;
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                if (object[@"error"]) {
                    MPLogError(@"%@ decide check api error: %@", self, object[@"error"]);
                    hadError = YES;
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                id rawAutomaticEvents = object[@"automatic_events"];
                if (rawAutomaticEvents != nil && [rawAutomaticEvents isKindOfClass:[NSNumber class]]) {
                    [self handlingAutomaticEventsWith: [rawAutomaticEvents boolValue]];
                }

                @synchronized (self) {
                    self.decideResponseCached = YES;
                }

                dispatch_semaphore_signal(semaphore);
            }] resume];

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        } else {
            MPLogInfo(@"%@ decide cache found, skipping network request", self);
        }
    });
}

#endif

@end
