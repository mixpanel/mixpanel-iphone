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


#define VERSION @"3.0.4"

@implementation Mixpanel

static Mixpanel *sharedInstance;
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken launchOptions:(NSDictionary *)launchOptions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
#if defined(DEBUG)
        const NSUInteger flushInterval = 1;
#else
        const NSUInteger flushInterval = 60;
#endif
        
        sharedInstance = [[super alloc] initWithToken:apiToken launchOptions:launchOptions andFlushInterval:flushInterval];
    });
    return sharedInstance;
}

+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken
{
    return [Mixpanel sharedInstanceWithToken:apiToken launchOptions:nil];
}

+ (Mixpanel *)sharedInstance
{
    if (sharedInstance == nil) {
        MPLogWarning(@"sharedInstance called before sharedInstanceWithToken:");
    }
    return sharedInstance;
}

- (instancetype)initWithToken:(NSString *)apiToken launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval
{
    if (apiToken.length == 0) {
        if (apiToken == nil) {
            apiToken = @"";
        }
        MPLogWarning(@"%@ empty api token", self);
    }
    if (self = [self init]) {
#if !defined(MIXPANEL_APP_EXTENSION)
        // Install uncaught exception handlers first
        [[MixpanelExceptionHandler sharedHandler] addMixpanelInstance:self];
#if !defined(MIXPANEL_TVOS_EXTENSION)
        self.telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
#endif
#endif
        MPSetLoggingEnabled(YES);
        
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
        self.checkForSurveysOnActive = YES;
        self.miniNotificationPresentationTime = 6.0;

        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.automaticProperties = [self collectAutomaticProperties];
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.taskId = UIBackgroundTaskInvalid;
        NSString *label = [NSString stringWithFormat:@"com.mixpanel.%@.%p", apiToken, (void *)self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        self.timedEvents = [NSMutableDictionary dictionary];

        self.showSurveyOnActive = YES;
#if defined(DISABLE_MIXPANEL_AB_DESIGNER) // Deprecated in v3.0.1
        self.enableVisualABTestAndCodeless = NO;
#else
        self.enableVisualABTestAndCodeless = YES;
#endif
        self.shownSurveyCollections = [NSMutableSet set];
        self.shownNotifications = [NSMutableSet set];
        
        self.network = [[MPNetwork alloc] initWithServerURL:[NSURL URLWithString:self.serverURL]];
        self.people = [[MixpanelPeople alloc] initWithMixpanel:self];

#if !defined(MIXPANEL_APP_EXTENSION)
        [self setUpListeners];
#endif
        [self unarchive];
#if !MIXPANEL_LIMITED_SUPPORT
        [self executeCachedVariants];
        [self executeCachedEventBindings];
#endif

#if !defined(MIXPANEL_TVOS_EXTENSION) && !defined(MIXPANEL_APP_EXTENSION)
        NSDictionary *remoteNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification) {
            [self trackPushNotification:remoteNotification event:@"$app_open"];
        }
#endif
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
    
#if !MIXPANEL_LIMITED_SUPPORT
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

#if !MIXPANEL_LIMITED_SUPPORT
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
    for (id __unused k in properties) {
        NSAssert([k isKindOfClass: [NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [k class], k);
        // would be convenient to do: id v = properties[k]; but
        // when the NSAssert's are stripped out in release, it becomes an
        // unused variable error. also, note that @YES and @NO pass as
        // instances of NSNumber class.
        NSAssert([properties[k] isKindOfClass:[NSString class]] ||
                 [properties[k] isKindOfClass:[NSNumber class]] ||
                 [properties[k] isKindOfClass:[NSNull class]] ||
                 [properties[k] isKindOfClass:[NSArray class]] ||
                 [properties[k] isKindOfClass:[NSDictionary class]] ||
                 [properties[k] isKindOfClass:[NSDate class]] ||
                 [properties[k] isKindOfClass:[NSURL class]],
                 @"%@ property values must be NSString, NSNumber, NSNull, NSArray, NSDictionary, NSDate or NSURL. got: %@ %@", self, [properties[k] class], properties[k]);
    }
}

- (NSString *)defaultDistinctId
{
    NSString *distinctId = [self IFA];

    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
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
        self.distinctId = distinctId;
        self.people.distinctId = distinctId;
        if (self.people.unidentifiedQueue.count > 0) {
            for (NSMutableDictionary *r in self.people.unidentifiedQueue) {
                r[@"$distinct_id"] = distinctId;
                [self.peopleQueue addObject:r];
            }
            [self.people.unidentifiedQueue removeAllObjects];
            [self archivePeople];
        }
        [self archiveProperties];
    });
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
    [self track:@"$create_alias" properties:@{ @"distinct_id": distinctID, @"alias": alias }];
    [self flush];
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
    
#if !MIXPANEL_LIMITED_SUPPORT
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
        
#if !MIXPANEL_LIMITED_SUPPORT
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
        [self.eventsQueue addObject:e];
        if (self.eventsQueue.count > 5000) {
            [self.eventsQueue removeObjectAtIndex:0];
        }
        
        // Always archive
        [self archiveEvents];
    });
#if defined(MIXPANEL_APP_EXTENSION)
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
    dispatch_async(self.serialQueue, ^{
        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.people.distinctId = nil;
        self.people.unidentifiedQueue = [NSMutableArray array];
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.timedEvents = [NSMutableDictionary dictionary];
        self.shownSurveyCollections = [NSMutableSet set];
        self.shownNotifications = [NSMutableSet set];
        self.decideResponseCached = NO;
        self.variants = [NSSet set];
        self.eventBindings = [NSSet set];
        [self archive];
    });
}

#pragma mark - Network control
- (void)setServerURL:(NSString *)serverURL
{
    _serverURL = serverURL.copy;
    self.network = [[MPNetwork alloc] initWithServerURL:[NSURL URLWithString:serverURL]];
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
    dispatch_async(self.serialQueue, ^{
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
    });
}

#pragma mark - Persistence
- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
#if !defined(MIXPANEL_TVOS_EXTENSION)
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
    NSMutableArray *eventsQueueCopy = [NSMutableArray arrayWithArray:[self.eventsQueue copy]];
    MPLogInfo(@"%@ archiving events data to %@: %@", self, filePath, eventsQueueCopy);
    if (![self archiveObject:eventsQueueCopy withFilePath:filePath]) {
        MPLogError(@"%@ unable to archive event data", self);
    }
}

- (void)archivePeople
{
    NSString *filePath = [self peopleFilePath];
    NSMutableArray *peopleQueueCopy = [NSMutableArray arrayWithArray:[self.peopleQueue copy]];
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
    [p setValue:self.superProperties forKey:@"superProperties"];
    [p setValue:self.people.distinctId forKey:@"peopleDistinctId"];
    [p setValue:self.people.unidentifiedQueue forKey:@"peopleUnidentifiedQueue"];
    [p setValue:self.shownSurveyCollections forKey:@"shownSurveyCollections"];
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
        self.superProperties = properties[@"superProperties"] ?: [NSMutableDictionary dictionary];
        self.people.distinctId = properties[@"peopleDistinctId"];
        self.people.unidentifiedQueue = properties[@"peopleUnidentifiedQueue"] ?: [NSMutableArray array];
        self.shownSurveyCollections = properties[@"shownSurveyCollections"] ?: [NSMutableSet set];
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
#if !MIXPANEL_LIMITED_SUPPORT
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

- (NSDictionary *)collectAutomaticProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    NSString *deviceModel = [self deviceModel];
    CGSize size = [UIScreen mainScreen].bounds.size;

    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_version"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_release"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$app_build_number"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_version_string"];
    [p setValue:[self IFA] forKey:@"$ios_ifa"];
    
#if !MIXPANEL_LIMITED_SUPPORT
    CTCarrier *carrier = [self.telephonyInfo subscriberCellularProvider];
    [p setValue:carrier.carrierName forKey:@"$carrier"];
#endif

    [p addEntriesFromDictionary:@{
                                  @"mp_lib": @"iphone",
                                  @"$lib_version": [self libVersion],
                                  @"$manufacturer": @"Apple",
                                  @"$os": [device systemName],
                                  @"$os_version": [device systemVersion],
                                  @"$model": deviceModel,
                                  @"mp_device_model": deviceModel, //legacy
                                  @"$screen_height": @((NSInteger)size.height),
                                  @"$screen_width": @((NSInteger)size.width)
                                  }];
    return [p copy];
}

+ (BOOL)inBackground
{
#if !defined(MIXPANEL_APP_EXTENSION)
    return [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
#else
    return NO;
#endif
}

#if !defined(MIXPANEL_APP_EXTENSION)

#pragma mark - UIApplication Events

- (void)setUpListeners
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

#if !defined(MIXPANEL_TVOS_EXTENSION)
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
    [notificationCenter addObserver:self
                           selector:@selector(setCurrentRadio)
                               name:CTRadioAccessTechnologyDidChangeNotification
                             object:nil];
#endif
    
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

    [self initializeGestureRecognizer];

}

- (void) initializeGestureRecognizer {
#if !defined(MIXPANEL_TVOS_EXTENSION)
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
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:self.testDesignerGestureRecognizer];
    });
#endif
}

#if !defined(MIXPANEL_TVOS_EXTENSION)

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

#endif

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    MPLogInfo(@"%@ application did become active", self);
    [self startFlushTimer];

#if !defined(MIXPANEL_TVOS_EXTENSION)
    if (self.checkForSurveysOnActive || self.checkForNotificationsOnActive || self.checkForVariantsOnActive) {
        NSDate *start = [NSDate date];

        [self checkForDecideResponseWithCompletion:^(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
            if (self.showNotificationOnActive && notifications.count > 0) {
                [self showNotificationWithObject:notifications[0]];
            } else if (self.showSurveyOnActive && surveys.count > 0) {
                [self showSurveyWithObject:surveys[0] withAlert:([start timeIntervalSinceNow] < -2.0)];
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
#endif
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    MPLogInfo(@"%@ application will resign active", self);
    [self stopFlushTimer];
}

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
        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithRequest:request completionHandler:^(NSData *responseData,
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

- (void)applicationWillTerminate:(NSNotification *)notification
{
    MPLogInfo(@"%@ application will terminate", self);
    dispatch_async(_serialQueue, ^{
       [self archive];
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

#if !defined(MIXPANEL_TVOS_EXTENSION)
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
    // This fixes the NSInternalInconsistencyException caused when we try present a
    // survey on a viewcontroller that is itself being presented.
    if ([viewController isBeingPresented] || [viewController isBeingDismissed]) {
        return NO;
    }

    if ([viewController isKindOfClass:UIAlertController.class]) {
        return NO;
    }

    return YES;
}

- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion
{
    [self checkForDecideResponseWithCompletion:completion useCache:YES];
}

- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion useCache:(BOOL)useCache
{
    dispatch_async(self.serialQueue, ^{
        NSMutableSet *newVariants = [NSMutableSet set];
        NSMutableSet *newEventBindings = [NSMutableSet set];

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
            NSURLSession *session = [NSURLSession sharedSession];
            [[session dataTaskWithRequest:request completionHandler:^(NSData *responseData,
                                                                      NSURLResponse *urlResponse,
                                                                      NSError *error) {

                if (error) {
                    MPLogError(@"%@ decide check http error: %@", self, error);
                    if (completion) {
                        completion(nil, nil, nil, nil);
                    }
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                // Handle network response
                NSDictionary *object = [NSJSONSerialization JSONObjectWithData:responseData options:(NSJSONReadingOptions)0 error:&error];
                if (error) {
                    MPLogError(@"%@ decide check json error: %@, data: %@", self, error, [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                    if (completion) {
                        completion(nil, nil, nil, nil);
                    }
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                if (object[@"error"]) {
                    MPLogError(@"%@ decide check api error: %@", self, object[@"error"]);
                    if (completion) {
                        completion(nil, nil, nil, nil);
                    }
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

                id rawSurveys = object[@"surveys"];
                NSMutableArray *parsedSurveys = [NSMutableArray array];
                if ([rawSurveys isKindOfClass:[NSArray class]]) {
                    for (id obj in rawSurveys) {
                        MPSurvey *survey = [MPSurvey surveyWithJSONObject:obj];
                        if (survey) {
                            [parsedSurveys addObject:survey];
                        }
                    }
                } else {
                    MPLogError(@"%@ survey check response format error: %@", self, object);
                }

                id rawNotifications = object[@"notifications"];
                NSMutableArray *parsedNotifications = [NSMutableArray array];
                if ([rawNotifications isKindOfClass:[NSArray class]]) {
                    for (id obj in rawNotifications) {
                        MPNotification *notification = [MPNotification notificationWithJSONObject:obj];
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
                
                self.surveys = [NSArray arrayWithArray:parsedSurveys];
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

        NSArray *unseenSurveys = [self.surveys objectsAtIndexes:[self.surveys indexesOfObjectsPassingTest:^BOOL(MPSurvey *obj, NSUInteger idx, BOOL *stop) {
            return [self.shownSurveyCollections member:@(obj.collectionID)] == nil;
        }]];

        NSArray *unseenNotifications = [self.notifications objectsAtIndexes:[self.notifications indexesOfObjectsPassingTest:^BOOL(MPNotification *obj, NSUInteger idx, BOOL *stop) {
            return [self.shownNotifications member:@(obj.ID)] == nil;
        }]];

        MPLogInfo(@"%@ decide check found %lu available surveys out of %lu total: %@", self, (unsigned long)unseenSurveys.count, (unsigned long)self.surveys.count, unseenSurveys);
        MPLogInfo(@"%@ decide check found %lu available notifs out of %lu total: %@", self, (unsigned long)unseenNotifications.count,
                      (unsigned long)self.notifications.count, unseenNotifications);
        MPLogInfo(@"%@ decide check found %lu variants: %@", self, (unsigned long)self.variants.count, self.variants);
        MPLogInfo(@"%@ decide check found %lu tracking events: %@", self, (unsigned long)self.eventBindings.count, self.eventBindings);

        if (completion) {
            completion(unseenSurveys, unseenNotifications, newVariants, newEventBindings);
        }
    });
}

- (void)checkForSurveysWithCompletion:(void (^)(NSArray *surveys))completion
{
    [self checkForDecideResponseWithCompletion:^(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
        if (completion) {
            completion(surveys);
        }
    } useCache:NO];
}

- (void)checkForNotificationsWithCompletion:(void (^)(NSArray *notifications))completion
{
    [self checkForDecideResponseWithCompletion:^(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
        if (completion) {
            completion(notifications);
        }
    } useCache:NO];
}

- (void)checkForVariantsWithCompletion:(void (^)(NSSet *variants))completion
{
    [self checkForDecideResponseWithCompletion:^(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
        if (completion) {
            completion(variants);
        }
    } useCache:NO];
}

#pragma mark - Surveys
- (BOOL)isSurveyAvailable {
    return (self.surveys.count > 0);
}

- (NSArray<MPSurvey *> *)availableSurveys {
    return self.surveys;
}

- (void)presentSurveyWithRootViewController:(MPSurvey *)survey
{
    UIViewController *presentingViewController = [Mixpanel topPresentedViewController];

    if ([[self class] canPresentFromViewController:presentingViewController]) {
        UIStoryboard *storyboard = [MPResources surveyStoryboard];
        MPSurveyNavigationController *controller = [storyboard instantiateViewControllerWithIdentifier:@"MPSurveyNavigationController"];
        controller.survey = survey;
        controller.delegate = self;
        controller.backgroundImage = [presentingViewController.view mp_snapshotImage];
        [presentingViewController presentViewController:controller animated:YES completion:nil];
    }
}

- (void)showSurveyWithObject:(MPSurvey *)survey withAlert:(BOOL)showAlert
{
    if (survey) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentlyShowingSurvey) {
                MPLogWarning(@"%@ already showing survey: %@", self, self.currentlyShowingSurvey);
            } else if (self.currentlyShowingNotification) {
                MPLogWarning(@"%@ already showing in-app notification: %@", self, self.currentlyShowingNotification);
            } else {
                self.currentlyShowingSurvey = survey;
                if (showAlert) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"We'd love your feedback!" message:@"Mind taking a quick survey?" preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"No, Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                        if (self.currentlyShowingSurvey) {
                            [self markSurvey:self.currentlyShowingSurvey shown:NO withAnswerCount:0];
                            self.currentlyShowingSurvey = nil;
                        }
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Sure" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        if (self.currentlyShowingSurvey) {
                            [self presentSurveyWithRootViewController:self.currentlyShowingSurvey];
                        }
                    }]];
                    [[Mixpanel topPresentedViewController] presentViewController:alert animated:YES completion:nil];
                    
                } else {
                    [self presentSurveyWithRootViewController:survey];
                }
            }
        });
    } else {
        MPLogError(@"%@ cannot show nil survey", self);
    }
}

- (void)showSurveyWithObject:(MPSurvey *)survey
{
    [self showSurveyWithObject:survey withAlert:NO];
}

- (void)showSurvey
{
    [self checkForSurveysWithCompletion:^(NSArray *surveys) {
        if (surveys.count > 0) {
            [self showSurveyWithObject:surveys[0]];
        }
    }];
}

- (void)showSurveyWithID:(NSUInteger)ID
{
    [self checkForSurveysWithCompletion:^(NSArray *surveys) {
        for (MPSurvey *survey in surveys) {
            if (survey.ID == ID) {
                [self showSurveyWithObject:survey];
                break;
            }
        }
    }];
}

- (void)markSurvey:(MPSurvey *)survey shown:(BOOL)shown withAnswerCount:(NSUInteger)count
{
    MPLogInfo(@"%@ marking survey shown: %@, %@", self, @(survey.collectionID), _shownSurveyCollections);
    [_shownSurveyCollections addObject:@(survey.collectionID)];
    [self.people append:@{@"$surveys": @(survey.ID), @"$collections": @(survey.collectionID)}];

    if (![survey.name isEqualToString:@"$ignore"]) {
        [self track:@"$show_survey" properties:@{@"survey_id": @(survey.ID),
                                                 @"collection_id": @(survey.collectionID),
                                                 @"$survey_shown": @(shown),
                                                 @"$answer_count": @(count)
                                                 }];
    }
}

- (void)surveyController:(MPSurveyNavigationController *)controller wasDismissedWithAnswers:(NSArray *)answers
{
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    self.currentlyShowingSurvey = nil;
    if ([controller.survey.name isEqualToString:@"$ignore"]) {
        MPLogInfo(@"%@ not sending survey %@ result, since survey is marked $ignore.", self, controller.survey);
    } else {
        [self markSurvey:controller.survey shown:YES withAnswerCount:answers.count];
        NSUInteger i = 0;
        for (id answer in answers) {
            if (i == 0) {
                [self.people append:@{@"$answers": answer, @"$responses": @(controller.survey.collectionID)}];
            } else {
                [self.people append:@{@"$answers": answer}];
            }
            i++;
        }
        
        dispatch_async(_serialQueue, ^{
            [self.network flushPeopleQueue:self.peopleQueue];
        });
    }
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
        } else if (self.currentlyShowingSurvey) {
            MPLogWarning(@"%@ already showing survey: %@", self, self.currentlyShowingSurvey);
        } else {
            self.currentlyShowingNotification = notification;
            BOOL shown;
            if ([notification.type isEqualToString:MPNotificationTypeMini]) {
                shown = [self showMiniNotificationWithObject:notification];
            } else {
                shown = [self showTakeoverNotificationWithObject:notification];
            }

            if (shown && ![notification.title isEqualToString:@"$ignore"]) {
                [self markNotificationShown:notification];
            }

            if (!shown) {
                self.currentlyShowingNotification = nil;
            }
        }
    });
}

- (BOOL)showTakeoverNotificationWithObject:(MPNotification *)notification
{
    UIViewController *presentingViewController = [Mixpanel topPresentedViewController];

    if ([[self class] canPresentFromViewController:presentingViewController]) {
        UIStoryboard *storyboard = [MPResources notificationStoryboard];
        MPTakeoverNotificationViewController *controller = [storyboard instantiateViewControllerWithIdentifier:@"MPNotificationViewController"];
        controller.backgroundImage = [presentingViewController.view mp_snapshotImage];
        controller.notification = notification;
        controller.delegate = self;
        self.notificationViewController = controller;

        [presentingViewController presentViewController:controller animated:YES completion:nil];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)showMiniNotificationWithObject:(MPNotification *)notification
{
    MPMiniNotificationViewController *controller = [[MPMiniNotificationViewController alloc] init];
    controller.notification = notification;
    controller.delegate = self;
    controller.backgroundColor = self.miniNotificationBackgroundColor;
    self.notificationViewController = controller;

    [controller showWithAnimation];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.miniNotificationPresentationTime * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self notificationController:controller wasDismissedWithStatus:NO];
    });
    return YES;
}

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithStatus:(BOOL)status
{
    if (controller == nil || self.currentlyShowingNotification != controller.notification) {
        return;
    }

    void (^completionBlock)() = ^void() {
        self.currentlyShowingNotification = nil;
        self.notificationViewController = nil;
    };

    if (status && controller.notification.callToActionURL) {
        [controller hideWithAnimation:YES completion:^{
            NSURL *URL = controller.notification.callToActionURL;
            MPLogInfo(@"%@ opening URL %@", self, URL);

            if (![[UIApplication sharedApplication] openURL:URL]) {
                MPLogError(@"Mixpanel failed to open given URL: %@", URL);
            }

            [self trackNotification:controller.notification event:@"$campaign_open"];
            completionBlock();
        }];
    } else {
        [controller hideWithAnimation:YES completion:completionBlock];
    }
}

- (void)trackNotification:(MPNotification *)notification event:(NSString *)event
{
    if (![notification.title isEqualToString:@"$ignore"]) {
        [self track:event properties:@{@"campaign_id": @(notification.ID),
                                       @"message_id": @(notification.messageID),
                                       @"message_type": @"inapp",
                                       @"message_subtype": notification.type}];
    } else {
        MPLogInfo(@"%@ ignoring notif track for %@, %@", self, @(notification.ID), event);
    }
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

#endif //MIXPANEL_TVOS_EXTENSION
#endif //MIXPANEL_APP_EXTENSION

@end
