#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MixpanelPeople.h"
#import "MixpanelPeoplePrivate.h"
#import "MPNetworkPrivate.h"

#import "MPLogger.h"
#import "MPFoundation.h"

#if defined(MIXPANEL_WATCHOS)
#import "MixpanelWatchProperties.h"
#import <WatchKit/WatchKit.h>
#elif defined(MIXPANEL_MACOS)
#import <IOKit/IOKitLib.h>
#endif

#define VERSION @"3.1.3"

@implementation Mixpanel

static NSMutableDictionary *instances;
static NSString *defaultProjectToken;

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken launchOptions:(NSDictionary *)launchOptions
{
    if (instances[apiToken]) {
        return instances[apiToken];
    }

#if defined(DEBUG)
    const NSUInteger flushInterval = 1;
#else
    const NSUInteger flushInterval = 60;
#endif

    return [[self alloc] initWithToken:apiToken launchOptions:launchOptions andFlushInterval:flushInterval];
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken
{
    return [Mixpanel sharedInstanceWithToken:apiToken launchOptions:nil];
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
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.timedEvents = [NSMutableDictionary dictionary];
        self.shownNotifications = [NSMutableSet set];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instances = [NSMutableDictionary dictionary];
            defaultProjectToken = apiToken;
        });
    }

    return self;
}

- (instancetype)initWithToken:(NSString *)apiToken launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval
{
    if (apiToken.length == 0) {
        if (apiToken == nil) {
            apiToken = @"";
        }
        MPLogWarning(@"%@ empty api token", self);
    }
    if (self = [self init:apiToken]) {
        // Install uncaught exception handlers first
        [[MixpanelExceptionHandler sharedHandler] addMixpanelInstance:self];
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
        self.telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
#endif
        self.apiToken = apiToken;
        _flushInterval = flushInterval;
        self.useIPAddressForGeoLocation = YES;
        self.shouldManageNetworkActivityIndicator = YES;
        self.flushOnBackground = YES;

        self.serverURL = @"https://api.mixpanel.com";
        self.switchboardURL = @"wss://switchboard.mixpanel.com";

        self.showNotificationOnActive = YES;
        self.checkForNotificationsOnActive = YES;
        self.checkForVariantsOnActive = YES;
        self.miniNotificationPresentationTime = 6.0;

        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.automaticProperties = [self collectAutomaticProperties];

#if !defined(MIXPANEL_WATCHOS) && !defined(MIXPANEL_MACOS)
        self.taskId = UIBackgroundTaskInvalid;
#endif
        NSString *label = [NSString stringWithFormat:@"com.mixpanel.%@.%p", apiToken, (void *)self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        NSString *networkLabel = [label stringByAppendingString:@".network"];
        self.networkQueue = dispatch_queue_create([networkLabel UTF8String], DISPATCH_QUEUE_SERIAL);

#if defined(DISABLE_MIXPANEL_AB_DESIGNER) // Deprecated in v3.0.1
        self.enableVisualABTestAndCodeless = NO;
#else
        self.enableVisualABTestAndCodeless = YES;
#endif
        
        self.network = [[MPNetwork alloc] initWithServerURL:[NSURL URLWithString:self.serverURL] mixpanel:self];
        self.people = [[MixpanelPeople alloc] initWithMixpanel:self];

        [self setUpListeners];
        [self unarchive];
#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
        [self executeCachedVariants];
        [self executeCachedEventBindings];

        NSDictionary *remoteNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification) {
            [self trackPushNotification:remoteNotification event:@"$app_open"];
        }
#endif
        instances[apiToken] = self;
    }
    return self;
}

- (instancetype)initWithToken:(NSString *)apiToken andFlushInterval:(NSUInteger)flushInterval
{
    return [self initWithToken:apiToken launchOptions:nil andFlushInterval:flushInterval];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
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

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
- (void)setValidationEnabled:(BOOL)validationEnabled {
    _validationEnabled = validationEnabled;
    
    if (_validationEnabled) {
        [Mixpanel setSharedAutomatedInstance:self];
    } else {
        [Mixpanel setSharedAutomatedInstance:nil];
    }
}
#endif

- (BOOL)shouldManageNetworkActivityIndicator {
    return self.network.shouldManageNetworkActivityIndicator;
}

- (void)setShouldManageNetworkActivityIndicator:(BOOL)shouldManageNetworkActivityIndicator {
    self.network.shouldManageNetworkActivityIndicator = shouldManageNetworkActivityIndicator;
}

- (BOOL)useIPAddressForGeoLocation {
    return self.network.useIPAddressForGeoLocation;
}

- (void)setUseIPAddressForGeoLocation:(BOOL)useIPAddressForGeoLocation {
    self.network.useIPAddressForGeoLocation = useIPAddressForGeoLocation;
}

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
#if defined(MIXPANEL_MACOS)
    distinctId = [self macOSIdentifier];
#else
    distinctId = [self IFA];
#endif

#if !defined(MIXPANEL_WATCHOS) && !defined(MIXPANEL_MACOS)
    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
#endif
    if (!distinctId) {
        MPLogInfo(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
    }
    return distinctId;
}

- (void)identify:(NSString *)distinctId
{
    if (distinctId.length == 0) {
        MPLogWarning(@"%@ cannot identify blank distinct id: %@", self, distinctId);
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        // identify only changes the distinct id if it doesn't match either the existing or the alias;
        // if it's new, blow away the alias as well.
        if (![distinctId isEqualToString:self.alias]) {
            if (![distinctId isEqualToString:self.distinctId]) {
                self.alias = nil;
                self.distinctId = distinctId;
            }
            self.people.distinctId = distinctId;
        }
        if (self.people.unidentifiedQueue.count > 0) {
            for (NSMutableDictionary *r in self.people.unidentifiedQueue) {
                r[@"$distinct_id"] = self.distinctId;
                @synchronized (self) {
                    [self.peopleQueue addObject:r];
                }
            }
            [self.people.unidentifiedQueue removeAllObjects];
            [self archivePeople];
        }
        [self archiveProperties];
    });
#if MIXPANEL_FLUSH_IMMEDIATELY
    [self flush];
#endif
}

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID
{
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
            [self archiveProperties];
        });
        [self track:@"$create_alias" properties:@{ @"distinct_id": distinctID, @"alias": alias }];
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
    if (event.length == 0) {
        MPLogWarning(@"%@ mixpanel track called with empty event parameter. using 'mp_event'", self);
        event = @"mp_event";
    }
    
#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
    // Safety check
    BOOL isAutomaticEvent = [event isEqualToString:kAutomaticEventName];
    if (isAutomaticEvent && !self.isValidationEnabled) return;
#endif
    
    properties = [properties copy];
    [Mixpanel assertPropertyTypes:properties];

    NSTimeInterval epochInterval = [[NSDate date] timeIntervalSince1970];
    NSNumber *epochSeconds = @(round(epochInterval));
    dispatch_async(self.serialQueue, ^{
        NSNumber *eventStartTime = self.timedEvents[event];
        NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:self.automaticProperties];
        p[@"token"] = self.apiToken;
        p[@"time"] = epochSeconds;
        if (eventStartTime) {
            [self.timedEvents removeObjectForKey:event];
            p[@"$duration"] = @([[NSString stringWithFormat:@"%.3f", epochInterval - [eventStartTime doubleValue]] floatValue]);
        }
        if (self.distinctId) {
            p[@"distinct_id"] = self.distinctId;
        }
        [p addEntriesFromDictionary:self.superProperties];
        if (properties) {
            [p addEntriesFromDictionary:properties];
        }
        
#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
        if (self.validationEnabled) {
            if (self.validationMode == AutomaticEventModeCount) {
                if (isAutomaticEvent) {
                    self.validationEventCount++;
                } else {
                    if (self.validationEventCount > 0) {
                        p[@"$__c"] = @(self.validationEventCount);
                        self.validationEventCount = 0;
                    }
                }
            }
        }
#endif
        
        NSDictionary *e = @{ @"event": event, @"properties": [NSDictionary dictionaryWithDictionary:p]} ;
        MPLogInfo(@"%@ queueing event: %@", self, e);
        @synchronized (self) {
            [self.eventsQueue addObject:e];
            if (self.eventsQueue.count > 5000) {
                [self.eventsQueue removeObjectAtIndex:0];
            }
        }

        // Always archive
        [self archiveEvents];
    });
#if MIXPANEL_FLUSH_IMMEDIATELY
    [self flush];
#endif
}


- (void)trackPushNotification:(NSDictionary *)userInfo event:(NSString *)event
{
    MPLogInfo(@"%@ tracking push payload %@", self, userInfo);

    id rawMp = userInfo[@"mp"];
    if (rawMp) {
        
        NSDictionary *mpPayload = [rawMp isKindOfClass:[NSDictionary class]] ? rawMp : nil;

        if (mpPayload[@"m"] && mpPayload[@"c"]) {
            [self track:event properties:@{@"campaign_id": mpPayload[@"c"],
                                           @"message_id": mpPayload[@"m"],
                                           @"message_type": @"push"}];
        } else {
            MPLogInfo(@"%@ malformed mixpanel push payload %@", self, mpPayload);
        }
    }
}

- (void)trackPushNotification:(NSDictionary *)userInfo
{
    [self trackPushNotification:userInfo event:@"$campaign_received"];
}

- (void)registerSuperProperties:(NSDictionary *)properties
{
    properties = [properties copy];
    [Mixpanel assertPropertyTypes:properties];
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        [tmp addEntriesFromDictionary:properties];
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveProperties];
    });
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties
{
    [self registerSuperPropertiesOnce:properties defaultValue:nil];
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(id)defaultValue
{
    properties = [properties copy];
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
        [self archiveProperties];
    });
}

- (void)unregisterSuperProperty:(NSString *)propertyName
{
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        tmp[propertyName] = nil;
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveProperties];
    });
}

- (void)clearSuperProperties
{
    dispatch_async(self.serialQueue, ^{
        self.superProperties = @{};
        [self archiveProperties];
    });
}

- (NSDictionary *)currentSuperProperties
{
    return [self.superProperties copy];
}

- (void)timeEvent:(NSString *)event
{
    NSNumber *startTime = @([[NSDate date] timeIntervalSince1970]);
    
    if (event.length == 0) {
        MPLogError(@"Mixpanel cannot time an empty event");
        return;
    }
    dispatch_async(self.serialQueue, ^{
        self.timedEvents[event] = startTime;
    });
}

- (void)clearTimedEvents
{   dispatch_async(self.serialQueue, ^{
        self.timedEvents = [NSMutableDictionary dictionary];
    });
}

- (void)reset
{
    [self flush];
    dispatch_async(self.serialQueue, ^{
        // wait for all current network requests to finish before resetting
        dispatch_sync(self.networkQueue, ^{ return; });

        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.people.distinctId = nil;
        self.alias = nil;
        self.people.unidentifiedQueue = [NSMutableArray array];
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.timedEvents = [NSMutableDictionary dictionary];
        self.shownNotifications = [NSMutableSet set];
        self.decideResponseCached = NO;
        self.variants = [NSSet set];
        self.eventBindings = [NSSet set];
#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
        [[MPTweakStore sharedInstance] reset];
#endif
        [self archive];
    });
}

- (void)dispatchOnNetworkQueue:(void (^)(void))dispatchBlock {
    // so this looks stupid but to make [Mixpanel track]; [Mixpanel flush]; continue to have the track
    // guaranteed to be part of the flush we need to make networkQueue stuff be dispatched on serialQueue
    // first. still will allow serialQueue stuff to happen at the same time as networkQueue stuff just
    // don't want to change track -> flush behavior that people may be relying on
    dispatch_async(self.serialQueue, ^{
        dispatch_async(self.networkQueue, dispatchBlock);
    });
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

- (void)flushWithCompletion:(void (^)())handler
{
    [self dispatchOnNetworkQueue:^{
        MPLogInfo(@"%@ flush starting", self);

        __strong id<MixpanelDelegate> strongDelegate = self.delegate;
        if (strongDelegate && [strongDelegate respondsToSelector:@selector(mixpanelWillFlush:)]) {
            if (![strongDelegate mixpanelWillFlush:self]) {
                MPLogInfo(@"%@ flush deferred by delegate", self);
                return;
            }
        }

        [self.network flushEventQueue:self.eventsQueue];
        [self.network flushPeopleQueue:self.peopleQueue];

        [self archive];

        if (handler) {
            dispatch_async(dispatch_get_main_queue(), handler);
        }

        MPLogInfo(@"%@ flush complete", self);
    }];
}

#pragma mark - Persistence
- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
#if !defined(MIXPANEL_TVOS)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
}

- (NSString *)eventsFilePath
{
    return [self filePathFor:@"events"];
}

- (NSString *)peopleFilePath
{
    return [self filePathFor:@"people"];
}

- (NSString *)propertiesFilePath
{
    return [self filePathFor:@"properties"];
}

- (NSString *)variantsFilePath
{
    return [self filePathFor:@"variants"];
}

- (NSString *)eventBindingsFilePath
{
    return [self filePathFor:@"event_bindings"];
}

- (void)archive
{
    [self archiveEvents];
    [self archivePeople];
    [self archiveProperties];
    [self archiveVariants];
    [self archiveEventBindings];
}

- (void)archiveEvents
{
    NSString *filePath = [self eventsFilePath];
    NSMutableArray *eventsQueueCopy;
    @synchronized (self) {
        eventsQueueCopy = [self.eventsQueue mutableCopy];
    }
    MPLogInfo(@"%@ archiving events data to %@: %@", self, filePath, eventsQueueCopy);
    if (![self archiveObject:eventsQueueCopy withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive event data", self);
    }
}

- (void)archivePeople
{
    NSString *filePath = [self peopleFilePath];
    NSMutableArray *peopleQueueCopy;
    @synchronized (self) {
        peopleQueueCopy = [self.peopleQueue mutableCopy];
    }
    MPLogInfo(@"%@ archiving people data to %@: %@", self, filePath, peopleQueueCopy);
    if (![self archiveObject:peopleQueueCopy withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive people data", self);
    }
}

- (void)archiveProperties
{
    NSString *filePath = [self propertiesFilePath];
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    [p setValue:self.distinctId forKey:@"distinctId"];
    [p setValue:self.alias forKey:@"alias"];
    [p setValue:self.superProperties forKey:@"superProperties"];
    [p setValue:self.people.distinctId forKey:@"peopleDistinctId"];
    [p setValue:self.people.unidentifiedQueue forKey:@"peopleUnidentifiedQueue"];
    [p setValue:self.shownNotifications forKey:@"shownNotifications"];
    [p setValue:self.timedEvents forKey:@"timedEvents"];
    MPLogInfo(@"%@ archiving properties data to %@: %@", self, filePath, p);
    if (![self archiveObject:p withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive properties data", self);
    }
}

- (void)archiveVariants
{
    NSString *filePath = [self variantsFilePath];
    if (![self archiveObject:self.variants withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive variants data", self);
    }
}

- (void)archiveEventBindings
{
    NSString *filePath = [self eventBindingsFilePath];
    if (![self archiveObject:self.eventBindings withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive tracking events data", self);
    }
}

- (BOOL)archiveObject:(id)object withFilePath:(NSString *)filePath {
    @try {
        if (![NSKeyedArchiver archiveRootObject:object toFile:filePath]) {
            return NO;
        }
    } @catch (NSException* exception) {
        NSAssert(@"Got exception: %@, reason: %@. You can only send to Mixpanel values that inherit from NSObject and implement NSCoding.", exception.name, exception.reason);
        return NO;
    }

    [self addSkipBackupAttributeToItemAtPath:filePath];
    return YES;
}

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)filePathString
{
    NSURL *URL = [NSURL fileURLWithPath: filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);

    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if (!success) {
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

- (void)unarchive
{
    [self unarchiveEvents];
    [self unarchivePeople];
    [self unarchiveProperties];
    [self unarchiveVariants];
    [self unarchiveEventBindings];
}

+ (nonnull id)unarchiveOrDefaultFromFile:(NSString *)filePath asClass:(Class)class
{
    return [self unarchiveFromFile:filePath asClass:class] ?: [class new];
}

+ (id)unarchiveFromFile:(NSString *)filePath asClass:(Class)class
{
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        // this check is inside the try-catch as the unarchivedData may be a non-NSObject, not responding to `isKindOfClass:` or `respondsToSelector:`
        if (![unarchivedData isKindOfClass:class]) {
            unarchivedData = nil;
        }
        MPLogInfo(@"%@ unarchived data from %@: %@", self, filePath, unarchivedData);
    }
    @catch (NSException *exception) {
        MPLogError(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        // Reset un archived data
        unarchivedData = nil;
        // Remove the (possibly) corrupt data from the disk
        NSError *error = NULL;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (!removed) {
            MPLogWarning(@"%@ unable to remove archived file at %@ - %@", self, filePath, error);
        }
    }
    return unarchivedData;
}

- (void)unarchiveEvents
{
    self.eventsQueue = (NSMutableArray *)[Mixpanel unarchiveOrDefaultFromFile:[self eventsFilePath] asClass:[NSMutableArray class]];
}

- (void)unarchivePeople
{
    self.peopleQueue = (NSMutableArray *)[Mixpanel unarchiveOrDefaultFromFile:[self peopleFilePath] asClass:[NSMutableArray class]];
}

- (void)unarchiveProperties
{
    NSDictionary *properties = (NSDictionary *)[Mixpanel unarchiveFromFile:[self propertiesFilePath] asClass:[NSDictionary class]];
    if (properties) {
        self.distinctId = properties[@"distinctId"] ?: [self defaultDistinctId];
        self.alias = properties[@"alias"];
        self.superProperties = properties[@"superProperties"] ?: [NSMutableDictionary dictionary];
        self.people.distinctId = properties[@"peopleDistinctId"];
        self.people.unidentifiedQueue = properties[@"peopleUnidentifiedQueue"] ?: [NSMutableArray array];
        self.shownNotifications = properties[@"shownNotifications"] ?: [NSMutableSet set];
        self.variants = properties[@"variants"] ?: [NSSet set];
        self.eventBindings = properties[@"event_bindings"] ?: [NSSet set];
        self.timedEvents = properties[@"timedEvents"] ?: [NSMutableDictionary dictionary];
    }
}

- (void)unarchiveVariants
{
    self.variants = (NSSet *)[Mixpanel unarchiveOrDefaultFromFile:[self variantsFilePath] asClass:[NSSet class]];
}

- (void)unarchiveEventBindings
{
    self.eventBindings = (NSSet *)[Mixpanel unarchiveOrDefaultFromFile:[self eventBindingsFilePath] asClass:[NSSet class]];
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

- (NSString *)watchModel
{
    NSString *model = nil;
    Class WKInterfaceDeviceClass = NSClassFromString(@"WKInterfaceDevice");
    if (WKInterfaceDeviceClass) {
        SEL currentDeviceSelector = NSSelectorFromString(@"currentDevice");
        id device = ((id (*)(id, SEL))[WKInterfaceDeviceClass methodForSelector:currentDeviceSelector])(WKInterfaceDeviceClass, currentDeviceSelector);
        SEL screenBoundsSelector = NSSelectorFromString(@"screenBounds");
        if (device && [device respondsToSelector:screenBoundsSelector]) {
            NSInvocation *screenBoundsInvocation = [NSInvocation invocationWithMethodSignature:[device methodSignatureForSelector:screenBoundsSelector]];
            [screenBoundsInvocation setSelector:screenBoundsSelector];
            [screenBoundsInvocation invokeWithTarget:device];
            CGRect screenBounds;
            [screenBoundsInvocation getReturnValue:(void *)&screenBounds];
            if (screenBounds.size.width == 136.0f) {
                model = @"Apple Watch 38mm";
            } else if (screenBounds.size.width == 156.0f) {
                model = @"Apple Watch 42mm";
            }
        }
    }
    return model;
}

- (NSString *)IFA
{
    NSString *ifa = nil;
#if !defined(MIXPANEL_NO_IFA)
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingTrackingEnabledSelector = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        BOOL isTrackingEnabled = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:advertisingTrackingEnabledSelector])(sharedManager, advertisingTrackingEnabledSelector);
        if (isTrackingEnabled) {
            SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
            NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
            ifa = [uuid UUIDString];
        }
    }
#endif
    return ifa;
}

#if defined(MIXPANEL_MACOS)
- (NSString *)macOSIdentifier {
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
    NSString *radio = _telephonyInfo.currentRadioAccessTechnology;
    if (!radio) {
        radio = @"None";
    } else if ([radio hasPrefix:@"CTRadioAccessTechnology"]) {
        radio = [radio substringFromIndex:23];
    }
    return radio;
#else 
    return @"";
#endif
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
#if defined(MIXPANEL_WATCHOS)
    return [MixpanelWatchProperties collectDeviceProperties];
#elif defined(MIXPANEL_MACOS)
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
    NSString *deviceModel = [self deviceModel];

    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_version"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_release"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_build_number"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_version_string"];
    [p setValue:[self IFA] forKey:@"$ios_ifa"];
    
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
    CTCarrier *carrier = [self.telephonyInfo subscriberCellularProvider];
    [p setValue:carrier.carrierName forKey:@"$carrier"];
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

+ (BOOL)inBackground
{
#if !MIXPANEL_NO_UIAPPLICATION_ACCESS
    return [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
#else
    return NO;
#endif
}

#pragma mark - UIApplication Events

#if !defined(MIXPANEL_MACOS)
- (void)setUpListeners
{
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                           selector:@selector(setCurrentRadio)
                               name:CTRadioAccessTechnologyDidChangeNotification
                             object:nil];
#endif // MIXPANEL_NO_REACHABILITY_SUPPORT

#if !MIXPANEL_NO_APP_LIFECYCLE_SUPPORT
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    // Application lifecycle events
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
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
    [notificationCenter addObserver:self
                           selector:@selector(appLinksNotificationRaised:)
                               name:@"com.parse.bolts.measurement_event"
                             object:nil];
#endif // MIXPANEL_NO_APP_LIFECYCLE_SUPPORT

    [self initializeGestureRecognizer];
}
#else
- (void)setUpListeners {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    // Application lifecycle events
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:NSApplicationWillTerminateNotification
                             object:nil];
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

- (void) initializeGestureRecognizer {
#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
    dispatch_async(dispatch_get_main_queue(), ^{
        self.testDesignerGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(connectGestureRecognized:)];
        self.testDesignerGestureRecognizer.minimumPressDuration = 3;
        self.testDesignerGestureRecognizer.cancelsTouchesInView = NO;
#if TARGET_IPHONE_SIMULATOR
        self.testDesignerGestureRecognizer.numberOfTouchesRequired = 2;
#else
        self.testDesignerGestureRecognizer.numberOfTouchesRequired = 4;
#endif
        // because this is in a dispatch_async, if the user sets enableVisualABTestAndCodeless in the first run
        // loop then this is initialized after that is set so we have to check here
        self.testDesignerGestureRecognizer.enabled = self.enableVisualABTestAndCodeless;
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:self.testDesignerGestureRecognizer];
    });
#endif // MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
}

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

#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
    if (self.checkForNotificationsOnActive || self.checkForVariantsOnActive) {

        [self checkForDecideResponseWithCompletion:^(NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
            if (self.showNotificationOnActive && notifications.count > 0) {
                [self showNotificationWithObject:notifications[0]];
            }
            dispatch_sync(dispatch_get_main_queue(), ^{
                for (MPVariant *variant in variants) {
                    [variant execute];
                    [self markVariantRun:variant];
                }
            });

            dispatch_sync(dispatch_get_main_queue(), ^{
                for (MPEventBinding *binding in eventBindings) {
                    [binding execute];
                }
            });
        }];
    }
#endif // MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    MPLogInfo(@"%@ application will resign active", self);
    [self stopFlushTimer];

#if defined(MIXPANEL_MACOS)
    if (self.flushOnBackground) {
        [self flush];
    }

    dispatch_async(_serialQueue, ^{
        [self archive];
    });
#endif
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    MPLogInfo(@"%@ application will terminate", self);
    dispatch_async(_serialQueue, ^{
        [self archive];
    });
}

#if !defined(MIXPANEL_MACOS)
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    MPLogInfo(@"%@ did enter background", self);
    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        MPLogInfo(@"%@ flush %lu cut short", self, (unsigned long) backgroundTask);
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        self.taskId = UIBackgroundTaskInvalid;
    }];
    self.taskId = backgroundTask;
    MPLogInfo(@"%@ starting background cleanup task %lu", self, (unsigned long)self.taskId);
    
    dispatch_group_t bgGroup = dispatch_group_create();
    NSString *trackedKey = [NSString stringWithFormat:@"MPTracked:%@", self.apiToken];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:trackedKey]) {
        dispatch_group_enter(bgGroup);
        NSString *requestData = [MPNetwork encodeArrayForAPI:@[@{@"event": @"Integration", @"properties": @{@"token": @"85053bf24bba75239b16a601d9387e17", @"mp_lib": @"iphone", @"distinct_id": self.apiToken}}]];
        NSString *postBody = [NSString stringWithFormat:@"ip=%d&data=%@", self.useIPAddressForGeoLocation, requestData];
        NSURLRequest *request = [self.network buildPostRequestForEndpoint:MPNetworkEndpointTrack andBody:postBody];
        [[[MPNetwork sharedURLSession] dataTaskWithRequest:request completionHandler:^(NSData *responseData,
                                                                  NSURLResponse *urlResponse,
                                                                  NSError *error) {
            if (!error) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:trackedKey];
            }
            dispatch_group_leave(bgGroup);
        }] resume];
    }
    
    if (self.flushOnBackground) {
        [self flush];
    }
    
    dispatch_group_enter(bgGroup);
    dispatch_async(_serialQueue, ^{
        [self archive];
        self.decideResponseCached = NO;
        dispatch_group_leave(bgGroup);
    });
    
    dispatch_group_notify(bgGroup, dispatch_get_main_queue(), ^{
        MPLogInfo(@"%@ ending background cleanup task %lu", self, (unsigned long)self.taskId);
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification
{
    MPLogInfo(@"%@ will enter foreground", self);
    dispatch_async(self.serialQueue, ^{
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
            [self.network updateNetworkActivityIndicator:NO];
        }
    });
}

- (void)appLinksNotificationRaised:(NSNotification *)notification
{
    NSDictionary *eventMap = @{@"al_nav_out": @"$al_nav_out",
                               @"al_nav_in": @"$al_nav_in",
                               @"al_ref_back_out": @"$al_ref_back_out"
                               };
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo[@"event_name"] && userInfo[@"event_args"] && eventMap[userInfo[@"event_name"]]) {
        [self track:eventMap[userInfo[@"event_name"]] properties:userInfo[@"event_args"]];
    }
}
#endif // MIXPANEL_MACOS

#endif // MIXPANEL_NO_APP_LIFECYCLE_SUPPORT

#pragma mark - Logging
- (void)setEnableLogging:(BOOL)enableLogging {
    gLoggingEnabled = enableLogging;

    if (gLoggingEnabled) {
        asl_add_log_file(NULL, STDERR_FILENO);
        asl_set_filter(NULL, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
    } else {
        asl_remove_log_file(NULL, STDERR_FILENO);
    }
}

- (BOOL)enableLogging {
    return gLoggingEnabled;
}

#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT

#pragma mark - Decide

+ (UIViewController *)topPresentedViewController
{
    UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (BOOL)canPresentFromViewController:(UIViewController *)viewController
{
    if ([viewController isBeingPresented] || [viewController isBeingDismissed]) {
        return NO;
    }

    if ([viewController isKindOfClass:UIAlertController.class]) {
        return NO;
    }

    return YES;
}

- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion
{
    [self checkForDecideResponseWithCompletion:completion useCache:YES];
}

- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion useCache:(BOOL)useCache
{
    [self dispatchOnNetworkQueue:^{
        NSMutableSet *newVariants = [NSMutableSet set];
        NSMutableSet *newEventBindings = [NSMutableSet set];
        __block BOOL hadError = NO;

        if (!useCache || !self.decideResponseCached) {
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

                NSDictionary *config = object[@"config"];
                if (config && [config isKindOfClass:NSDictionary.class]) {
                    NSDictionary *validationConfig = config[@"ce"];
                    if (validationConfig && [validationConfig isKindOfClass:NSDictionary.class]) {
                        self.validationEnabled = [validationConfig[@"enabled"] boolValue];

                        NSString *method = validationConfig[@"method"];
                        if (method && [method isKindOfClass:NSString.class]) {
                            if ([method isEqualToString:@"count"]) {
                                self.validationMode = AutomaticEventModeCount;
                            }
                        }
                    }
                }

                id rawNotifications = object[@"notifications"];
                NSMutableArray *parsedNotifications = [NSMutableArray array];
                if ([rawNotifications isKindOfClass:[NSArray class]]) {
                    for (id obj in rawNotifications) {
                        MPNotification *notification = nil;
                        NSString *notificationType = obj[@"type"];
                        if ([notificationType isEqualToString:MPNotificationTypeTakeover]) {
                            notification = [[MPTakeoverNotification alloc] initWithJSONObject:obj];
                        } else if ([notificationType isEqualToString:MPNotificationTypeMini]) {
                            notification = [[MPMiniNotification alloc] initWithJSONObject:obj];
                        }
                        
                        if (notification) {
                            [parsedNotifications addObject:notification];
                        }
                    }
                } else {
                    MPLogError(@"%@ in-app notifs check response format error: %@", self, object);
                }

                id rawVariants = object[@"variants"];
                NSMutableSet *parsedVariants = [NSMutableSet set];
                if ([rawVariants isKindOfClass:[NSArray class]]) {
                    for (id obj in rawVariants) {
                        MPVariant *variant = [MPVariant variantWithJSONObject:obj];
                        if (variant) {
                            [parsedVariants addObject:variant];
                        }
                    }
                } else {
                    MPLogError(@"%@ variants check response format error: %@", self, object);
                }

                // Variants that are already running (may or may not have been marked as finished).
                NSSet *runningVariants = [NSSet setWithSet:[self.variants objectsPassingTest:^BOOL(MPVariant *var, BOOL *stop) { return var.running; }]];
                // Variants that are marked as finished, (may or may not be running still).
                NSSet *finishedVariants = [NSSet setWithSet:[self.variants objectsPassingTest:^BOOL(MPVariant *var, BOOL *stop) { return var.finished; }]];
                // Variants that are running that should be marked finished.
                NSMutableSet *toFinishVariants = [NSMutableSet setWithSet:runningVariants];
                [toFinishVariants minusSet:parsedVariants];
                // New variants that we just saw that are not already running.
                [newVariants unionSet:parsedVariants];
                [newVariants minusSet:runningVariants];
                // Running variants that were marked finished, but have now started again.
                NSMutableSet *restartVariants = [NSMutableSet setWithSet:parsedVariants];
                [restartVariants intersectSet:runningVariants];
                [restartVariants intersectSet:finishedVariants];
                // All variants that we still care about (stopped are thrown out)
                NSMutableSet *allVariants = [NSMutableSet setWithSet:newVariants];
                [allVariants unionSet:runningVariants];

                [restartVariants makeObjectsPerformSelector:NSSelectorFromString(@"restart")];
                [toFinishVariants makeObjectsPerformSelector:NSSelectorFromString(@"finish")];

                id rawEventBindings = object[@"event_bindings"];
                NSMutableSet *parsedEventBindings = [NSMutableSet set];
                if ([rawEventBindings isKindOfClass:[NSArray class]]) {
                    for (id obj in rawEventBindings) {
                        MPEventBinding *binder = [MPEventBinding bindingWithJSONObject:obj];
                        if (binder) {
                            [parsedEventBindings addObject:binder];
                        }
                    }
                } else {
                    MPLogDebug(@"%@ mp tracking events check response format error: %@", self, object);
                }

                // Finished bindings are those which should no longer be run.
                NSMutableSet *finishedEventBindings = [NSMutableSet setWithSet:self.eventBindings];
                [finishedEventBindings minusSet:parsedEventBindings];
                [finishedEventBindings makeObjectsPerformSelector:NSSelectorFromString(@"stop")];

                // New bindings are those we are running for the first time.
                [newEventBindings unionSet:parsedEventBindings];
                [newEventBindings minusSet:self.eventBindings];

                NSMutableSet *allEventBindings = [self.eventBindings mutableCopy];
                [allEventBindings unionSet:newEventBindings];

                self.notifications = [NSArray arrayWithArray:parsedNotifications];
                self.variants = [allVariants copy];
                self.eventBindings = [allEventBindings copy];

                self.decideResponseCached = YES;

                dispatch_semaphore_signal(semaphore);
            }] resume];

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        } else {
            MPLogInfo(@"%@ decide cache found, skipping network request", self);
        }

        if (hadError) {
            if (completion) {
                completion(nil, nil, nil);
            }
        } else {
            NSArray *unseenNotifications = [self.notifications objectsAtIndexes:[self.notifications indexesOfObjectsPassingTest:^BOOL(MPNotification *obj, NSUInteger idx, BOOL *stop) {
                return [self.shownNotifications member:@(obj.ID)] == nil;
            }]];

            MPLogInfo(@"%@ decide check found %lu available notifs out of %lu total: %@", self, (unsigned long)unseenNotifications.count,
                      (unsigned long)self.notifications.count, unseenNotifications);
            MPLogInfo(@"%@ decide check found %lu variants: %@", self, (unsigned long)self.variants.count, self.variants);
            MPLogInfo(@"%@ decide check found %lu tracking events: %@", self, (unsigned long)self.eventBindings.count, self.eventBindings);

            if (completion) {
                completion(unseenNotifications, newVariants, newEventBindings);
            }
        }
    }];
}

- (void)checkForNotificationsWithCompletion:(void (^)(NSArray *notifications))completion
{
    [self checkForDecideResponseWithCompletion:^(NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
        if (completion) {
            completion(notifications);
        }
    } useCache:NO];
}

- (void)checkForVariantsWithCompletion:(void (^)(NSSet *variants))completion
{
    [self checkForDecideResponseWithCompletion:^(NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
        if (completion) {
            completion(variants);
        }
    } useCache:NO];
}

#pragma mark - Mixpanel Notifications

- (void)showNotification
{
    [self checkForNotificationsWithCompletion:^(NSArray *notifications) {
        if (notifications.count > 0) {
            [self showNotificationWithObject:notifications[0]];
        }
    }];
}

- (void)showNotificationWithType:(NSString *)type
{
    [self checkForNotificationsWithCompletion:^(NSArray *notifications) {
        if (type != nil) {
            for (MPNotification *notification in notifications) {
                if ([notification.type isEqualToString:type]) {
                    [self showNotificationWithObject:notification];
                    break;
                }
            }
        }
    }];
}

- (void)showNotificationWithID:(NSUInteger)ID
{
    [self checkForNotificationsWithCompletion:^(NSArray *notifications) {
        for (MPNotification *notification in notifications) {
            if (notification.ID == ID) {
                [self showNotificationWithObject:notification];
                break;
            }
        }
    }];
}

- (void)showNotificationWithObject:(MPNotification *)notification
{
    NSData *image = notification.image;

    // if images fail to load, remove the notification from the queue
    if (!image) {
        NSMutableArray *notifications = [NSMutableArray arrayWithArray:_notifications];
        [notifications removeObject:notification];
        self.notifications = [NSArray arrayWithArray:notifications];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.currentlyShowingNotification) {
            MPLogWarning(@"%@ already showing in-app notification: %@", self, self.currentlyShowingNotification);
        } else {
            self.currentlyShowingNotification = notification;
            BOOL shown;
            if ([notification.type isEqualToString:MPNotificationTypeMini]) {
                shown = [self showMiniNotificationWithObject:(MPMiniNotification *)notification];
            } else {
                shown = [self showTakeoverNotificationWithObject:(MPTakeoverNotification *)notification];
            }

            if (shown) {
                [self markNotificationShown:notification];
            } else {
                self.currentlyShowingNotification = nil;
            }
        }
    });
}

- (BOOL)showTakeoverNotificationWithObject:(MPTakeoverNotification *)notification
{
    UIViewController *presentingViewController = [Mixpanel topPresentedViewController];

    if ([[self class] canPresentFromViewController:presentingViewController]) {
        MPTakeoverNotificationViewController *controller = [[MPTakeoverNotificationViewController alloc] init];
        controller.notification = notification;
        controller.delegate = self;
        [controller show];
        self.notificationViewController = controller;

        return YES;
    } else {
        return NO;
    }
}

- (BOOL)showMiniNotificationWithObject:(MPMiniNotification *)notification
{
    MPMiniNotificationViewController *controller = [[MPMiniNotificationViewController alloc] init];
    controller.notification = notification;
    controller.delegate = self;
    self.notificationViewController = controller;

    [controller show];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.miniNotificationPresentationTime * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self notificationController:controller wasDismissedWithCtaUrl:nil];
    });
    return YES;
}

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithCtaUrl:(NSURL *)ctaUrl
{
    if (controller == nil || self.currentlyShowingNotification != controller.notification) {
        return;
    }

    void (^completionBlock)() = ^void() {
        self.currentlyShowingNotification = nil;
        self.notificationViewController = nil;
    };

    if (ctaUrl) {
        [controller hide:YES completion:^{
            MPLogInfo(@"%@ opening URL %@", self, ctaUrl);

            if (![[UIApplication sharedApplication] openURL:ctaUrl]) {
                MPLogError(@"Mixpanel failed to open given URL: %@", ctaUrl);
            }

            [self trackNotification:controller.notification event:@"$campaign_open"];
            completionBlock();
        }];
    } else {
        [controller hide:YES completion:completionBlock];
    }
}

- (void)trackNotification:(MPNotification *)notification event:(NSString *)event
{
    [self track:event properties:@{@"campaign_id": @(notification.ID),
                                   @"message_id": @(notification.messageID),
                                   @"message_type": @"inapp",
                                   @"message_subtype": notification.type}];
}

- (void)markNotificationShown:(MPNotification *)notification
{
    MPLogInfo(@"%@ marking notification shown: %@, %@", self, @(notification.ID), _shownNotifications);

    [_shownNotifications addObject:@(notification.ID)];

    NSDictionary *properties = @{
                                 @"$campaigns": @(notification.ID),
                                 @"$notifications": @{
                                         @"campaign_id": @(notification.ID),
                                         @"message_id": @(notification.messageID),
                                         @"type": @"inapp",
                                         @"time": [NSDate date]
                                         }
                                 };

    [self.people append:properties];

    [self trackNotification:notification event:@"$campaign_delivery"];
}

#pragma mark - Mixpanel A/B Testing and Codeless (Designer)
- (void)setEnableVisualABTestAndCodeless:(BOOL)enableVisualABTestAndCodeless {
    _enableVisualABTestAndCodeless = enableVisualABTestAndCodeless;

    self.testDesignerGestureRecognizer.enabled = _enableVisualABTestAndCodeless;
    if (!_enableVisualABTestAndCodeless) {
        // Note that the connection will be closed and cleaned up properly in the dealloc method
        [self.abtestDesignerConnection close];
        self.abtestDesignerConnection = nil;
    }
}

- (BOOL)enableVisualABTestAndCodeless {
    return _enableVisualABTestAndCodeless;
}

- (void)connectGestureRecognized:(id)sender
{
    if (!sender || ([sender isKindOfClass:[UIGestureRecognizer class]] && ((UIGestureRecognizer *)sender).state == UIGestureRecognizerStateBegan)) {
        [self connectToABTestDesigner];
    }
}

- (void)connectToABTestDesigner
{
    [self connectToABTestDesigner:NO];
}

- (void)connectToABTestDesigner:(BOOL)reconnect
{
    // Ignore the gesture if the AB test designer is disabled.
    if (!self.enableVisualABTestAndCodeless) return;
    
    if ([self.abtestDesignerConnection isKindOfClass:[MPABTestDesignerConnection class]] && ((MPABTestDesignerConnection *)self.abtestDesignerConnection).connected) {
        MPLogWarning(@"A/B test designer connection already exists");
        return;
    }
    static NSUInteger oldInterval;
    NSString *designerURLString = [NSString stringWithFormat:@"%@/connect?key=%@&type=device", self.switchboardURL, self.apiToken];
    NSURL *designerURL = [NSURL URLWithString:designerURLString];
    __weak Mixpanel *weakSelf = self;
    void (^connectCallback)(void) = ^{
        __strong Mixpanel *strongSelf = weakSelf;
        oldInterval = strongSelf.flushInterval;
        strongSelf.flushInterval = 1;
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        if (strongSelf) {
            for (MPVariant *variant in self.variants) {
                [variant stop];
            }
            for (MPEventBinding *binding in self.eventBindings) {
                [binding stop];
            }
            MPABTestDesignerConnection *connection = strongSelf.abtestDesignerConnection;
            void (^block)(id, SEL, NSString*, id) = ^(id obj, SEL sel, NSString *event_name, id params) {
                MPDesignerTrackMessage *message = [MPDesignerTrackMessage messageWithPayload:@{@"event_name": event_name}];
                [connection sendMessage:message];
            };
            
            [MPSwizzler swizzleSelector:@selector(track:properties:) onClass:[Mixpanel class] withBlock:block named:@"track_properties"];
        }
    };
    void (^disconnectCallback)(void) = ^{
        __strong Mixpanel *strongSelf = weakSelf;
        strongSelf.flushInterval = oldInterval;
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        if (strongSelf) {
            for (MPVariant *variant in self.variants) {
                [variant execute];
            }
            for (MPEventBinding *binding in self.eventBindings) {
                [binding execute];
            }
            [MPSwizzler unswizzleSelector:@selector(track:properties:) onClass:[Mixpanel class] named:@"track_properties"];
        }
    };
    self.abtestDesignerConnection = [[MPABTestDesignerConnection alloc] initWithURL:designerURL
                                                                         keepTrying:reconnect
                                                                    connectCallback:connectCallback
                                                                 disconnectCallback:disconnectCallback];
}

#pragma mark - Mixpanel A/B Testing (Experiment)

- (void)executeCachedVariants {
    for (MPVariant *variant in self.variants) {
        NSAssert(!variant.running, @"Variant should not be running at this point");
        [variant execute];
    }
}

- (void)markVariantRun:(MPVariant *)variant
{
    MPLogInfo(@"%@ marking variant %@ shown for experiment %@", self, @(variant.ID), @(variant.experimentID));
    NSDictionary *shownVariant = @{@(variant.experimentID).stringValue: @(variant.ID)};
    if (self.people.distinctId) {
        [self.people merge:@{@"$experiments": shownVariant}];
    }

    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *superProperties = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        NSMutableDictionary *shownVariants = [NSMutableDictionary dictionaryWithDictionary:superProperties[@"$experiments"]];
        [shownVariants addEntriesFromDictionary:shownVariant];
        [superProperties addEntriesFromDictionary:@{@"$experiments": [shownVariants copy]}];
        self.superProperties = [superProperties copy];
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });

    [self track:@"$experiment_started" properties:@{@"$experiment_id": @(variant.experimentID), @"$variant_id": @(variant.ID)}];
}

- (void)joinExperimentsWithCallback:(void(^)())experimentsLoadedCallback
{
    [self checkForVariantsWithCompletion:^(NSSet *newVariants) {
        for (MPVariant *variant in newVariants) {
            [variant execute];
            [self markVariantRun:variant];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (experimentsLoadedCallback) {
                experimentsLoadedCallback();
            }
        });
    }];
}

- (void)joinExperiments
{
    [self joinExperimentsWithCallback:nil];
}

#pragma mark - Mixpanel Event Bindings

- (void)executeCachedEventBindings {
    for (id binding in self.eventBindings) {
        if ([binding isKindOfClass:[MPEventBinding class]]) {
            [binding execute];
        }
    }
}

#endif // MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT

@end
