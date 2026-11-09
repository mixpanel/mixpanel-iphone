#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#import <objc/runtime.h>
#import <TargetConditionals.h>
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

#define VERSION @"5.0.8"
#define DEVICE_PREFIX @"$device:"

// Identifies the serial queue, so work already on it can read state without dispatch_sync
static void *const MPSerialQueueKey = (void *)&MPSerialQueueKey;


@implementation Mixpanel

static NSMutableDictionary *instances;
static NSString *defaultProjectToken;

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
static CTTelephonyNetworkInfo *telephonyInfo;
#endif

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:trackCrashes optOutTrackingByDefault:NO useUniqueDistinctId:NO];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes optOutTrackingByDefault:(BOOL)optOutTrackingByDefault useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    return [self sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:trackCrashes optOutTrackingByDefault:optOutTrackingByDefault useUniqueDistinctId:useUniqueDistinctId hierarchicalGroups:NO];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents hierarchicalGroups:(BOOL)hierarchicalGroups
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:YES optOutTrackingByDefault:NO useUniqueDistinctId:NO hierarchicalGroups:hierarchicalGroups];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes optOutTrackingByDefault:(BOOL)optOutTrackingByDefault useUniqueDistinctId:(BOOL)useUniqueDistinctId hierarchicalGroups:(BOOL)hierarchicalGroups
{
    if (instances[apiToken]) {
        return instances[apiToken];
    }

#if defined(DEBUG)
    const NSUInteger flushInterval = 2;
#else
    const NSUInteger flushInterval = 60;
#endif

    return [[self alloc] initWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents flushInterval:flushInterval trackCrashes:trackCrashes optOutTrackingByDefault:optOutTrackingByDefault useUniqueDistinctId:useUniqueDistinctId hierarchicalGroups:hierarchicalGroups];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:YES];
}


+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents optOutTrackingByDefault:(BOOL)optOutTrackingByDefault
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:YES optOutTrackingByDefault:optOutTrackingByDefault useUniqueDistinctId:NO];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    return [Mixpanel sharedInstanceWithToken:apiToken trackAutomaticEvents:trackAutomaticEvents trackCrashes:YES optOutTrackingByDefault:NO useUniqueDistinctId:useUniqueDistinctId];
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
         trackAutomaticEvents:(BOOL)trackAutomaticEvents
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
      optOutTrackingByDefault:(BOOL)optOutTrackingByDefault
          useUniqueDistinctId:(BOOL)useUniqueDistinctId
           hierarchicalGroups:(BOOL)hierarchicalGroups
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
        _hierarchicalGroups = hierarchicalGroups;
        _trackAutomaticEventsEnabled = trackAutomaticEvents;
        _flushInterval = flushInterval;
        self.persistence = [[MixpanelPersistence alloc] initWithToken: apiToken];
        [self.persistence migrate];
        self.useIPAddressForGeoLocation = YES;
        self.shouldManageNetworkActivityIndicator = YES;
        self.flushOnBackground = YES;

        self.serverURL = @"https://api.mixpanel.com";
        self.useUniqueDistinctId = useUniqueDistinctId;
        self.anonymousId = [self defaultDeviceId];
        self.eventsDistinctId = [DEVICE_PREFIX stringByAppendingString:self.anonymousId];
        self.superProperties = [NSDictionary dictionary];
        self.automaticProperties = [self collectAutomaticProperties];

#if !TARGET_OS_WATCH && !TARGET_OS_OSX
        if (![Mixpanel isAppExtension]) {
            self.taskId = UIBackgroundTaskInvalid;
        }
#endif
        NSString *label = [NSString stringWithFormat:@"com.mixpanel.%@.%p", apiToken, (void *)self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.serialQueue, MPSerialQueueKey, (__bridge void *)self, NULL);
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
        instances[apiToken] = self;
    }
    return self;
}

- (instancetype)initWithToken:(NSString *)apiToken
         trackAutomaticEvents:(BOOL)trackAutomaticEvents
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
          useUniqueDistinctId:(BOOL)useUniqueDistinctId
{
    return [self initWithToken:apiToken
          trackAutomaticEvents:trackAutomaticEvents
                 flushInterval:flushInterval
                  trackCrashes:trackCrashes
       optOutTrackingByDefault:NO
           useUniqueDistinctId:useUniqueDistinctId
            hierarchicalGroups:NO];
}

- (instancetype)initWithToken:(NSString *)apiToken
         trackAutomaticEvents:(BOOL)trackAutomaticEvents
             andFlushInterval:(NSUInteger)flushInterval
{
    return [self initWithToken:apiToken
          trackAutomaticEvents:trackAutomaticEvents
                 flushInterval:flushInterval
                  trackCrashes:NO
           useUniqueDistinctId:NO];
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
    _trackAutomaticEventsEnabled = trackAutomaticEventsEnabled;
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

- (NSString *)defaultDeviceId
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

- (MixpanelPersistedIdentity *)currentMixpanelIdentity
{
    return [[MixpanelPersistedIdentity alloc] initWithDistinctId:self.eventsDistinctId peopleDistinctId:self.people.distinctId
                                                     anonymousId:self.anonymousId userId:self.userId companyId:self.companyId
                                                           alias:self.alias hadPersistedDistinctId:self.hadPersistedDistinctId];
}

// Runs block on the serial queue and waits, so it sees every earlier call. Runs it in place when
// already on the serial queue, which would otherwise deadlock.
- (void)performSyncOnSerialQueue:(dispatch_block_t)block
{
    if (dispatch_get_specific(MPSerialQueueKey) == (__bridge void *)self) {
        block();
    } else {
        dispatch_sync(self.serialQueue, block);
    }
}

// distinctId is computed, so setting eventsDistinctId posts its KVO. On a hierarchical groups project it
// also reads userId, companyId and anonymousId, so the paths that change them post one distinctId
// notification around the whole change and set eventsDistinctId with
// setEventsDistinctIdWithoutNotification:.
+ (NSSet<NSString *> *)keyPathsForValuesAffectingDistinctId
{
    return [NSSet setWithObject:@"eventsDistinctId"];
}

// The Objective-C runtime function behind a synthesized atomic copy setter
OBJC_EXPORT void objc_setProperty_atomic_copy(id self, SEL _cmd, id newValue, ptrdiff_t offset);

// Sets eventsDistinctId exactly as its atomic copy setter does, but without the KVO notification the
// setter posts, for callers that post the distinctId notification themselves.
- (void)setEventsDistinctIdWithoutNotification:(NSString *)eventsDistinctId
{
    static ptrdiff_t offset;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        offset = ivar_getOffset(class_getInstanceVariable([Mixpanel class], "_eventsDistinctId"));
    });
    objc_setProperty_atomic_copy(self, @selector(setEventsDistinctId:), eventsDistinctId, offset);
}

- (NSString *)distinctId
{
    if (!self.hierarchicalGroups) {
        return self.eventsDistinctId;
    }
    __block NSString *distinctId;
    [self performSyncOnSerialQueue:^{
        NSString *userId = self.userId;
        if (!userId) {
            // Anonymous, so already $device:{deviceId}
            distinctId = self.eventsDistinctId;
        } else if (self.companyId) {
            distinctId = [NSString stringWithFormat:@"$company:%@|$user:%@", self.companyId, userId];
        } else if (self.anonymousId) {
            // Mixpanel ignores a user id without a company while the event carries a device id
            distinctId = [DEVICE_PREFIX stringByAppendingString:self.anonymousId];
        } else {
            distinctId = self.eventsDistinctId;
        }
    }];
    return distinctId;
}

- (MixpanelIdentity *)identity
{
    __block MixpanelIdentity *identity;
    [self performSyncOnSerialQueue:^{
        identity = [[MixpanelIdentity alloc] initWithUserId:self.userId
                                                  companyId:(self.hierarchicalGroups ? self.companyId : nil)
                                                   deviceId:self.anonymousId];
    }];
    return identity;
}

- (void)identify:(NSString *)distinctId
{
    [self identify:distinctId usePeople:YES];
}

- (void)identify:(NSString *)distinctId usePeople:(BOOL)usePeople
{
    if (self.hierarchicalGroups) {
        MPLogError(@"identify: is not supported for hierarchical groups projects, which identify a user by company "
                   @"and user id. Use identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:userId companyId:companyId]. "
                   @"Nothing was identified.");
        return;
    }
    [self identify:distinctId companyId:nil usePeople:usePeople];
}

- (void)identifyWithIdentity:(MixpanelIdentity *)identity
{
    if ([self hasOptedOutTracking]) {
        return;
    }
    if (identity == nil) {
        MPLogError(@"Can't identify with a nil MixpanelIdentity.");
        return;
    }
    NSString *identityError = [self identityError:identity];
    if (identityError) {
        MPLogError(@"%@ Nothing was identified.", identityError);
        return;
    }
    NSString *userId = identity.userId;
    NSString *companyId = identity.companyId;
    NSString *deviceId = identity.deviceId;
    NSString *anonymousId = self.anonymousId;
    if (deviceId != nil && ![deviceId isEqualToString:anonymousId]) {
        MPLogWarning(@"Ignoring deviceId %@ on %@. The SDK owns the device id (%@) so earlier anonymous events follow "
                     @"the user.", deviceId, identity, anonymousId);
    }
    [self identify:userId companyId:companyId usePeople:YES];
}

// Why an identity can't be used on this project, or nil when it can. Callers add what was dropped.
- (NSString *)identityError:(MixpanelIdentity *)identity
{
    NSString *userId = identity.userId;
    NSString *companyId = identity.companyId;
    if (self.hierarchicalGroups) {
        if ([Mixpanel isBlankId:userId] || [Mixpanel isBlankId:companyId]) {
            return [NSString stringWithFormat:@"Can't identify %@: hierarchical groups projects identify a user by "
                    @"company and user id, so both are required.", identity];
        }
    } else {
        if ([Mixpanel isBlankId:userId]) {
            return [NSString stringWithFormat:@"Can't identify %@ without a user id.", identity];
        }
        if (companyId != nil) {
            return [NSString stringWithFormat:@"Can't identify %@: a company requires hierarchicalGroups:YES when "
                    @"initializing Mixpanel. Mixpanel ignores $company_id on other projects.", identity];
        }
    }
    if ([userId hasPrefix:DEVICE_PREFIX]) {
        return [NSString stringWithFormat:@"Can't identify %@: user ids starting with %@ are reserved for device ids.",
                identity, DEVICE_PREFIX];
    }
    return nil;
}

// Whether an id is nil, empty or only whitespace. The id itself is used as given, never trimmed.
+ (BOOL)isBlankId:(NSString *)identifier
{
    return [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0;
}

- (void)identify:(NSString *)distinctId companyId:(NSString *)companyId usePeople:(BOOL)usePeople
{
    if ([self hasOptedOutTracking]) {
        return;
    }

    if (distinctId.length == 0) {
        MPLogWarning(@"%@ cannot identify blank distinct id: %@", self, distinctId);
        return;
    }

    dispatch_async(self.serialQueue, ^{
        if(!self.anonymousId) {
            self.anonymousId = self.eventsDistinctId;
            self.hadPersistedDistinctId = YES;
        }
        // identify only changes the distinct id if it doesn't match the ID
        // if it's new, blow away the alias as well.
        BOOL userChanged = ![distinctId isEqualToString:self.eventsDistinctId];
        // A user in another company is another user, so a new company is an identity change.
        BOOL companyChanged = self.hierarchicalGroups && companyId != nil && ![companyId isEqualToString:self.companyId];
        if (userChanged || companyChanged) {
            NSString *oldDistinctId = [self.eventsDistinctId copy];
            self.alias = nil;
            if (self.hierarchicalGroups) {
                // distinctId reads all three, so observers get one notification around the whole change
                [self willChangeValueForKey:@"distinctId"];
                self.companyId = companyId;
                self.userId = distinctId;
                [self setEventsDistinctIdWithoutNotification:distinctId];
                [self didChangeValueForKey:@"distinctId"];
            } else {
                self.eventsDistinctId = distinctId;
                self.userId = distinctId;
            }
            // A hierarchical groups project ties the device to the user from the identity keys on later
            // events, so it has no $identify
            if (!self.hierarchicalGroups) {
                [self track:@"$identify" properties:@{@"$anon_distinct_id": oldDistinctId}];
            }
        }
        if (usePeople) {
            self.people.distinctId = distinctId;
            [self.persistence identifyPeople];
            if (self.hierarchicalGroups) {
                [self.persistence identifyHierarchicalGroupsPeopleWithUserId:distinctId companyId:self.companyId];
            }
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

    if (self.hierarchicalGroups) {
        MPLogError(@"createAlias is not supported for hierarchical groups projects, which identify a user by company "
                   @"and user id. Use identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:userId companyId:companyId]. "
                   @"The alias was dropped.");
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
    
    if (!self.trackAutomaticEventsEnabled && [event hasPrefix:@"$ae_"]) {
        return;
    }
    
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
        // The stored id, not the distinctId property. On a hierarchical groups project an identified
        // user is $user_id and $company_id, so no distinct_id
        if (self.eventsDistinctId && !(self.hierarchicalGroups && self.userId && self.companyId)) {
            p[@"distinct_id"] = self.eventsDistinctId;
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
        if (self.hierarchicalGroups) {
            // $company_id is part of the user's identity, so it is only ever the identified company
            id callerCompanyId = properties[MPCompanyIdGroupKey];
            if (self.companyId) {
                if (callerCompanyId != nil && ![callerCompanyId isEqual:self.companyId]) {
                    MPLogWarning(@"%@ event %@ has $company_id %@, which hierarchical groups projects set from the "
                                 @"identified company. Sending the identified company %@ instead.",
                                 self, event, callerCompanyId, self.companyId);
                }
                p[MPCompanyIdGroupKey] = self.companyId;
            } else if (p[MPCompanyIdGroupKey] != nil) {
                if (callerCompanyId != nil) {
                    MPLogWarning(@"%@ event %@ has $company_id %@ before a company is identified. Hierarchical groups "
                                 @"projects set it with identifyWithIdentity:, so it was removed from the event.",
                                 self, event, callerCompanyId);
                }
                [p removeObjectForKey:MPCompanyIdGroupKey];
            }
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
    if (self.hierarchicalGroups) {
        // Hierarchical groups read a list as the name of one group, not as membership in each
        for (id groupKey in groups) {
            id groupID = groups[groupKey];
            if ([groupID isKindOfClass:[NSArray class]] || [groupID isKindOfClass:[NSSet class]]) {
                MPLogError(@"trackWithGroups with a list is not supported for hierarchical groups projects, which allow "
                           @"one %@ per user. Use one group id per key. The event was dropped.", groupKey);
                return;
            }
        }
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

    if (self.hierarchicalGroups) {
        [self logSingleGroupOnly:@"addGroup" groupKey:groupKey];
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
    if (self.hierarchicalGroups) {
        if ([self refusesCompanyIdKey:groupKey operation:@"removeGroup"]) {
            return;
        }
        [self removeHierarchicalGroup:groupKey groupID:groupID];
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
    if (self.hierarchicalGroups) {
        if (![self refusesCompanyIdKey:groupKey operation:@"setGroup"]) {
            [self logSingleGroupOnly:@"setGroup with a list" groupKey:groupKey];
        }
        return;
    }
    NSDictionary *properties = @{groupKey : groupIDs};
    [self registerSuperProperties:properties];
    [self.people set:properties];
}

- (void)setGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    if (self.hierarchicalGroups) {
        [self setHierarchicalGroup:groupKey groupID:groupID];
        return;
    }
    NSArray *groupIDs = @[ groupID ];
    [self setGroup:groupKey groupIDs:groupIDs];
}

- (void)setHierarchicalGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    if ([self hasOptedOutTracking]) {
        return;
    }
    if (groupKey == nil || groupID == nil) {
        MPLogWarning(@"groupKey and groupID must be non-nil");
        return;
    }
    if ([self refusesCompanyIdKey:groupKey operation:@"setGroup"]) {
        return;
    }
    // Hierarchical groups read a list as the name of one group, not as membership in each
    if ([(NSObject *)groupID isKindOfClass:[NSArray class]] || [(NSObject *)groupID isKindOfClass:[NSSet class]]) {
        [self logSingleGroupOnly:@"setGroup with a list" groupKey:groupKey];
        return;
    }
    NSDictionary *properties = @{groupKey : groupID};
    [self registerSuperProperties:properties];
    [self.people set:properties];
}

// On a hierarchical groups project $company_id is the identified company, set only by
// identifyWithIdentity:, so a public call that names it is refused whole.
- (BOOL)refusesCompanyIdKey:(NSString *)key operation:(NSString *)operation {
    if (!self.hierarchicalGroups || ![key isKindOfClass:[NSString class]] || ![key isEqualToString:MPCompanyIdGroupKey]) {
        return NO;
    }
    MPLogError(@"%@ with $company_id is not supported for hierarchical groups projects, where $company_id is the "
               @"identified company. Use identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:userId "
               @"companyId:companyId]. Nothing was changed.", operation);
    return YES;
}

- (BOOL)refusesCompanyIdIn:(NSDictionary *)properties operation:(NSString *)operation {
    return self.hierarchicalGroups && properties[MPCompanyIdGroupKey] != nil
        && [self refusesCompanyIdKey:MPCompanyIdGroupKey operation:operation];
}

- (void)logSingleGroupOnly:(NSString *)operation groupKey:(NSString *)groupKey {
    MPLogError(@"%@ is not supported for hierarchical groups projects, which allow one %@ per user. "
               @"Use setGroup:groupID:. The update was dropped.", operation, groupKey);
}

- (void)removeHierarchicalGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID {
    if (groupKey == nil || groupID == nil) {
        MPLogWarning(@"groupKey and groupID must be non-nil");
        return;
    }
    [self updateSuperPropertiesAsync:^NSDictionary *(NSDictionary *superProps) {
        id value = superProps[groupKey];
        // A one-item list, stored by an earlier version or before hierarchical groups was
        // enabled, counts as that item
        if ([value isKindOfClass:[NSArray class]] && [(NSArray *)value count] == 1) {
            value = [(NSArray *)value firstObject];
        }
        if (value == nil || ![groupID equalToMixpanelType:value]) {
            return superProps;
        }
        NSMutableDictionary *mutableSuperProps = [superProps mutableCopy];
        [mutableSuperProps removeObjectForKey:groupKey];
        // Saved here on the serial queue rather than queued again with people unset:, so it keeps its
        // place before later group and profile updates and stays with the current user
        NSNumber *epochMilliseconds = @(round([[NSDate date] timeIntervalSince1970] * 1000));
        [self.people saveHierarchicalGroupsRecordWithAction:@"$unset" properties:@{@"$properties": @[groupKey]}
                                                       time:epochMilliseconds];
#if MIXPANEL_FLUSH_IMMEDIATELY
        [self flush];
#else
        if ([Mixpanel isAppExtension]) {
            [self flush];
        }
#endif
        return mutableSuperProps;
    }];
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

- (nullable MixpanelGroup *)getCompany {
    if (!self.hierarchicalGroups) {
        MPLogError(@"getCompany is only for hierarchical groups projects, "
                   @"enabled with hierarchicalGroups:YES when initializing Mixpanel.");
        return nil;
    }
    // Waits for earlier identify calls, so the company is the one current at call time
    __block NSString *companyId;
    [self performSyncOnSerialQueue:^{
        companyId = self.companyId;
    }];
    if (companyId == nil) {
        MPLogError(@"getCompany needs a company. Call "
                   @"identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:userId companyId:companyId] first.");
        return nil;
    }
    return [self getGroup:MPCompanyIdGroupKey groupID:companyId];
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
    if ([self refusesCompanyIdIn:properties operation:@"registerSuperProperties"]) {
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
    if ([self refusesCompanyIdIn:properties operation:@"registerSuperPropertiesOnce"]) {
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
    if ([self refusesCompanyIdKey:propertyName operation:@"unregisterSuperProperty"]) {
        return;
    }
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
        if (self.hierarchicalGroups) {
            // distinctId reads the ids changed below, so observers get one notification around the whole change
            [self willChangeValueForKey:@"distinctId"];
            self.anonymousId = [self defaultDeviceId];
            self.userId = nil;
            self.companyId = nil;
            [self setEventsDistinctIdWithoutNotification:[DEVICE_PREFIX stringByAppendingString:self.anonymousId]];
            [self didChangeValueForKey:@"distinctId"];
        } else {
            self.anonymousId = [self defaultDeviceId];
            self.eventsDistinctId = [DEVICE_PREFIX stringByAppendingString:self.anonymousId];
        }
        self.superProperties = [NSDictionary dictionary];
        self.userId = nil;
        self.companyId = nil;
        self.people.distinctId = nil;
        self.alias = nil;
        self.hadPersistedDistinctId = NO;
        self.cachedGroups = [NSMutableDictionary dictionary];
        self.timedEvents = [NSMutableDictionary dictionary];
        [self.persistence resetEntities];
        [self archive];
    });
}


- (void)optOutTracking{
    if (self.people.distinctId) {
        [self.people deleteUser];
        // trackCharge has no hierarchical groups equivalent, so there are no charges to clear
        if (!self.hierarchicalGroups) {
            [self.people clearCharges];
        }
        [self flush];
    }
    dispatch_async(self.serialQueue, ^{
        self.alias = nil;
        self.people.distinctId = nil;
        if (self.hierarchicalGroups) {
            // distinctId reads the ids changed below, so observers get one notification around the whole change
            [self willChangeValueForKey:@"distinctId"];
            self.userId = nil;
            self.companyId = nil;
            self.anonymousId = [self defaultDeviceId];
            // A hierarchical groups project keeps an anonymous user under $device:, as reset does
            [self setEventsDistinctIdWithoutNotification:[DEVICE_PREFIX stringByAppendingString:self.anonymousId]];
            [self didChangeValueForKey:@"distinctId"];
        } else {
            self.userId = nil;
            self.companyId = nil;
            self.anonymousId = [self defaultDeviceId];
            self.eventsDistinctId = self.anonymousId;
        }
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
    if (self.hierarchicalGroups) {
        [self optInTrackingWithIdentity:nil properties:nil];
    } else {
        [self optInTrackingForDistinctID:nil withEventProperties:nil];
    }
}

- (void)optInTrackingForDistinctID:(NSString *)distinctID
{
    [self optInTrackingForDistinctID:distinctID withEventProperties:nil];
}

- (void)optInTrackingForDistinctID:(NSString *)distinctID withEventProperties:(NSDictionary *)properties
{
    // A nil id identifies no one, so it is a plain opt-in on any project
    if (distinctID != nil && self.hierarchicalGroups) {
        MPLogError(@"optInTrackingForDistinctID: with a distinct id is not supported for hierarchical groups projects, "
                   @"which identify a user by company and user id. Use optInTrackingWithIdentity:[[MixpanelIdentity "
                   @"alloc] initWithUserId:userId companyId:companyId] properties:properties. The user is still opted out.");
        return;
    }
    self.optOutStatus = NO;
    [MixpanelPersistence saveOptOutStatusFlag:NO apiToken:self.apiToken];
    if (distinctID) {
        [self identify:distinctID];
    }
    [self track:@"$opt_in" properties:properties];
}

- (void)optInTrackingWithIdentity:(MixpanelIdentity *)identity properties:(NSDictionary *)properties
{
    NSString *identityError = identity ? [self identityError:identity] : nil;
    if (identityError) {
        MPLogError(@"%@ The user is still opted out.", identityError);
        return;
    }
    self.optOutStatus = NO;
    [MixpanelPersistence saveOptOutStatusFlag:NO apiToken:self.apiToken];
    if (identity) {
        [self identifyWithIdentity:identity];
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
    MixpanelPersistedIdentity *mixpanelIdentity = [MixpanelPersistence loadIdentity:self.apiToken];
    self.eventsDistinctId = mixpanelIdentity.distinctId;
    self.people.distinctId = mixpanelIdentity.peopleDistinctId;
    self.anonymousId = mixpanelIdentity.anonymousId;
    self.userId = mixpanelIdentity.userId;
    if (self.hierarchicalGroups) {
        self.companyId = mixpanelIdentity.companyId;
    }
    self.alias = mixpanelIdentity.alias;
    self.hadPersistedDistinctId = mixpanelIdentity.hadPersistedDistinctId;
    if (!self.eventsDistinctId) {
        self.anonymousId = [self defaultDeviceId];
        self.eventsDistinctId = [DEVICE_PREFIX stringByAppendingString:self.anonymousId];
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

#pragma mark - Logging
- (void)setEnableLogging:(BOOL)enableLogging
{
    [MPLogger sharedInstance].loggingEnabled = enableLogging;
}

- (BOOL)enableLogging
{
    return [MPLogger sharedInstance].loggingEnabled;
}

@end
