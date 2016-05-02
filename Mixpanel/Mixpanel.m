#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#import "Mixpanel.h"
#import "MPLogger.h"
#import "NSData+MPBase64.h"
#import "MPFoundation.h"
#import "Mixpanel+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"

#if !defined(MIXPANEL_APP_EXTENSION)

#import <CommonCrypto/CommonDigest.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIDevice.h>

#import "MPResources.h"
#import "MixpanelExceptionHandler.h"
#import "MPABTestDesignerConnection.h"
#import "UIView+MPHelpers.h"
#import "MPDesignerEventBindingMessage.h"
#import "MPDesignerSessionCollection.h"
#import "MPEventBinding.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"
#import "MPSurveyNavigationController.h"
#import "MPSwizzler.h"
#import "MPVariant.h"
#import "MPWebSocket.h"

#endif

#define VERSION @"2.9.9"

#if !defined(MIXPANEL_APP_EXTENSION)
@interface Mixpanel () <UIAlertViewDelegate, MPSurveyNavigationControllerDelegate, MPNotificationViewControllerDelegate>

#else
@interface Mixpanel () <UIAlertViewDelegate>

#endif
{
    NSUInteger _flushInterval;
}

#if !defined(MIXPANEL_APP_EXTENSION)
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
#endif

// re-declare internally as readwrite
@property (atomic, strong) MixpanelPeople *people;
@property (atomic, copy) NSString *distinctId;
@property (nonatomic, getter=isValidationEnabled) BOOL validationEnabled;
@property (nonatomic) AutomaticEventMode validationMode;
@property (nonatomic) NSUInteger validationEventCount;

@property (nonatomic, copy) NSString *apiToken;
@property (atomic, strong) NSDictionary *superProperties;
@property (atomic, strong) NSDictionary *automaticProperties;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSMutableArray *peopleQueue;
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskId;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableDictionary *timedEvents;

@property (nonatomic) BOOL decideResponseCached;

@property (nonatomic, strong) NSArray *surveys;
@property (nonatomic, strong) id currentlyShowingSurvey;
@property (nonatomic, strong) NSMutableSet *shownSurveyCollections;

@property (nonatomic, strong) NSArray *notifications;
@property (nonatomic, strong) id currentlyShowingNotification;
@property (nonatomic, strong) UIViewController *notificationViewController;
@property (nonatomic, strong) NSMutableSet *shownNotifications;

@property (nonatomic, strong) id abtestDesignerConnection;
@property (nonatomic, strong) NSSet *variants;
@property (nonatomic, strong) NSSet *eventBindings;

@property (atomic, copy) NSString *decideURL;
@property (atomic, copy) NSString *switchboardURL;
@property (nonatomic) NSTimeInterval networkRequestsAllowedAfterTime;
@property (nonatomic) NSUInteger networkConsecutiveFailures;

@end

@interface MixpanelPeople ()

@property (nonatomic, weak) Mixpanel *mixpanel;
@property (nonatomic, strong) NSMutableArray *unidentifiedQueue;
@property (nonatomic, copy) NSString *distinctId;
@property (nonatomic, strong) NSDictionary *automaticPeopleProperties;

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel;
- (void)merge:(NSDictionary *)properties;

@end

@implementation Mixpanel

static Mixpanel *sharedInstance = nil;
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
        MixpanelDebug(@"warning sharedInstance called before sharedInstanceWithToken:");
    }
    return sharedInstance;
}

- (instancetype)initWithToken:(NSString *)apiToken launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval
{
    if (apiToken == nil) {
        apiToken = @"";
    }
    if ([apiToken length] == 0) {
        MixpanelDebug(@"%@ warning empty api token", self);
    }
    if (self = [self init]) {
#if !defined(MIXPANEL_APP_EXTENSION)
        // Install uncaught exception handlers first
        [[MixpanelExceptionHandler sharedHandler] addMixpanelInstance:self];
        self.telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
#endif
        
        self.networkRequestsAllowedAfterTime = 0;
        self.people = [[MixpanelPeople alloc] initWithMixpanel:self];
        self.apiToken = apiToken;
        _flushInterval = flushInterval;
        self.flushOnBackground = YES;
        self.showNetworkActivityIndicator = YES;
        self.useIPAddressForGeoLocation = YES;

        self.serverURL = @"https://api.mixpanel.com";
        self.decideURL = @"https://decide.mixpanel.com";
        self.switchboardURL = @"wss://switchboard.mixpanel.com";

        self.showNotificationOnActive = YES;
        self.checkForNotificationsOnActive = YES;
        self.checkForVariantsOnActive = YES;
        self.checkForSurveysOnActive = YES;
        self.miniNotificationPresentationTime = 6.0;
        self.miniNotificationBackgroundColor = nil;

        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.automaticProperties = [self collectAutomaticProperties];
        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        self.taskId = UIBackgroundTaskInvalid;
        NSString *label = [NSString stringWithFormat:@"com.mixpanel.%@.%p", apiToken, (void *)self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [_dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        self.timedEvents = [NSMutableDictionary dictionary];

        self.decideResponseCached = NO;
        self.showSurveyOnActive = YES;
        self.surveys = nil;
        self.currentlyShowingSurvey = nil;
        self.shownSurveyCollections = [NSMutableSet set];
        self.shownNotifications = [NSMutableSet set];
        self.currentlyShowingNotification = nil;
        self.notifications = nil;
        self.variants = nil;

#if !defined(MIXPANEL_APP_EXTENSION)
        [self setUpListeners];
#endif
        [self unarchive];
#if !defined(MIXPANEL_APP_EXTENSION)
        [self executeCachedVariants];
        [self executeCachedEventBindings];
#if defined(DEBUG) && !defined(DISABLE_MIXPANEL_AB_DESIGNER)
        [self connectToABTestDesigner:YES];
#endif
#endif

        if (launchOptions && launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
            [self trackPushNotification:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] event:@"$app_open"];
        }
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
    
#if !defined(MIXPANEL_APP_EXTENSION)
    if (_reachability != NULL) {
        if (!SCNetworkReachabilitySetCallback(_reachability, NULL, NULL)) {
            MixpanelError(@"%@ error unsetting reachability callback", self);
        }
        if (!SCNetworkReachabilitySetDispatchQueue(_reachability, NULL)) {
            MixpanelError(@"%@ error unsetting reachability dispatch queue", self);
        }
        CFRelease(_reachability);
        _reachability = NULL;
        MixpanelDebug(@"released reachability");
    }
#endif
}

- (void)setValidationEnabled:(BOOL)validationEnabled {
    _validationEnabled = validationEnabled;
    
    if (_validationEnabled) {
        [Mixpanel setSharedAutomatedInstance:self];
    } else {
        [Mixpanel setSharedAutomatedInstance:nil];
    }
}

#pragma mark - Encoding/decoding utilities

static __unused NSString *MPURLEncode(NSString *s)
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)s, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
}

- (NSData *)JSONSerializeObject:(id)obj
{
    id coercedObj = [self JSONSerializableObjectForObject:obj];
    NSError *error = nil;
    NSData *data = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:coercedObj options:(NSJSONWritingOptions)0 error:&error];
    }
    @catch (NSException *exception) {
        MixpanelError(@"%@ exception encoding api data: %@", self, exception);
    }
    if (error) {
        MixpanelError(@"%@ error encoding api data: %@", self, error);
    }
    return data;
}

- (id)JSONSerializableObjectForObject:(id)obj
{
    // valid json types
    if ([obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }
    // recurse on containers
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self JSONSerializableObjectForObject:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                MixpanelDebug(@"%@ warning: property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            } else {
                stringKey = [NSString stringWithString:key];
            }
            id v = [self JSONSerializableObjectForObject:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    // some common cases
    if ([obj isKindOfClass:[NSDate class]]) {
        return [self.dateFormatter stringFromDate:obj];
    } else if ([obj isKindOfClass:[NSURL class]]) {
        return [obj absoluteString];
    }
    // default to sending the object's description
    NSString *s = [obj description];
    MixpanelDebug(@"%@ warning: property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

- (NSString *)encodeAPIData:(NSArray *)array
{
    NSString *b64String = @"";
    NSData *data = [self JSONSerializeObject:array];
    if (data) {
        b64String = [data mp_base64EncodedString];
        b64String = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                (__bridge CFStringRef)b64String,
                                                                NULL,
                                                                CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                kCFStringEncodingUTF8));
    }
    return b64String;
}

#pragma mark - Tracking

+ (void)assertPropertyTypes:(NSDictionary *)properties
{
    for (id __unused k in properties) {
        NSAssert([k isKindOfClass: [NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [k class], k);
        // would be convenient to do: id v = [properties objectForKey:k]; but
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
        MixpanelDebug(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
    }
    return distinctId;
}


- (void)identify:(NSString *)distinctId
{
    if (distinctId == nil || distinctId.length == 0) {
        MixpanelDebug(@"%@ cannot identify blank distinct id: %@", self, distinctId);
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        self.distinctId = distinctId;
        self.people.distinctId = distinctId;
        if ([self.people.unidentifiedQueue count] > 0) {
            for (NSMutableDictionary *r in self.people.unidentifiedQueue) {
                r[@"$distinct_id"] = distinctId;
                [self.peopleQueue addObject:r];
            }
            [self.people.unidentifiedQueue removeAllObjects];
            [self archivePeople];
        }
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });
}

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID
{
    if (!alias || [alias length] == 0) {
        MixpanelError(@"%@ create alias called with empty alias: %@", self, alias);
        return;
    }
    if (!distinctID || [distinctID length] == 0) {
        MixpanelError(@"%@ create alias called with empty distinct id: %@", self, distinctID);
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
    if (event == nil || [event length] == 0) {
        MixpanelError(@"%@ mixpanel track called with empty event parameter. using 'mp_event'", self);
        event = @"mp_event";
    }
    
    // Safety check
    BOOL isAutomaticEvent = [event isEqualToString:kAutomaticEventName];
    if (isAutomaticEvent && !self.isValidationEnabled) return;
    
    properties = [properties copy];
    [Mixpanel assertPropertyTypes:properties];

    NSTimeInterval epochInterval = [[NSDate date] timeIntervalSince1970];
    NSNumber *epochSeconds = @(round(epochInterval));
    dispatch_async(self.serialQueue, ^{
        NSNumber *eventStartTime = self.timedEvents[event];
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        [p addEntriesFromDictionary:self.automaticProperties];
        p[@"token"] = self.apiToken;
        p[@"time"] = epochSeconds;
        if (eventStartTime) {
            [self.timedEvents removeObjectForKey:event];
            p[@"$duration"] = @([[NSString stringWithFormat:@"%.3f", epochInterval - [eventStartTime doubleValue]] floatValue]);
        }
        if (self.nameTag) {
            p[@"mp_name_tag"] = self.nameTag;
        }
        if (self.distinctId) {
            p[@"distinct_id"] = self.distinctId;
        }
        [p addEntriesFromDictionary:self.superProperties];
        if (properties) {
            [p addEntriesFromDictionary:properties];
        }
        
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
        
        NSDictionary *e = @{ @"event": event, @"properties": [NSDictionary dictionaryWithDictionary:p]} ;
        MixpanelDebug(@"%@ queueing event: %@", self, e);
        [self.eventsQueue addObject:e];
        if ([self.eventsQueue count] > 5000) {
            [self.eventsQueue removeObjectAtIndex:0];
        }
        
        if ([Mixpanel inBackground]) {
            [self archiveEvents];
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
    MixpanelDebug(@"%@ tracking push payload %@", self, userInfo);

    if (userInfo && userInfo[@"mp"]) {
        NSDictionary *mpPayload = userInfo[@"mp"];

        if ([mpPayload isKindOfClass:[NSDictionary class]] && mpPayload[@"m"] && mpPayload[@"c"]) {
            [self track:event properties:@{@"campaign_id": mpPayload[@"c"],
                                           @"message_id": mpPayload[@"m"],
                                           @"message_type": @"push"}];
        } else {
            MixpanelError(@"%@ malformed mixpanel push payload %@", self, mpPayload);
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
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
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
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });
}

- (void)unregisterSuperProperty:(NSString *)propertyName
{
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        if (tmp[propertyName] != nil) {
            [tmp removeObjectForKey:propertyName];
        }
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });
}

- (void)clearSuperProperties
{
    dispatch_async(self.serialQueue, ^{
        self.superProperties = @{};
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });
}

- (NSDictionary *)currentSuperProperties
{
    return [self.superProperties copy];
}

- (void)timeEvent:(NSString *)event
{
    NSNumber *startTime = @([[NSDate date] timeIntervalSince1970]);
    
    if (event == nil || [event length] == 0) {
        MixpanelError(@"Mixpanel cannot time an empty event");
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
        self.nameTag = nil;
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

- (NSUInteger)flushInterval
{
    @synchronized(self) {
        return _flushInterval;
    }
}

- (void)setFlushInterval:(NSUInteger)interval
{
    @synchronized(self) {
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
            MixpanelDebug(@"%@ started flush timer: %@", self, self.timer);
        }
    });
}

- (void)stopFlushTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
            MixpanelDebug(@"%@ stopped flush timer: %@", self, self.timer);
        }
        self.timer = nil;
    });
}

- (void)flush
{
    [self flushWithCompletion:nil];
}

- (void)flushWithCompletion:(void (^)())handler
{
    dispatch_async(self.serialQueue, ^{
        MixpanelDebug(@"%@ flush starting", self);

        __strong id<MixpanelDelegate> strongDelegate = self.delegate;
        if (strongDelegate && [strongDelegate respondsToSelector:@selector(mixpanelWillFlush:)]) {
            if (![strongDelegate mixpanelWillFlush:self]) {
                MixpanelDebug(@"%@ flush deferred by delegate", self);
                return;
            }
        }

        [self flushEvents];
        [self flushPeople];
        [self archive];
        
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), handler);
        }

        MixpanelDebug(@"%@ flush complete", self);
    });
}

- (void)flushEvents
{
    [self flushQueue:_eventsQueue
            endpoint:@"/track/"];
}

- (void)flushPeople
{
    [self flushQueue:_peopleQueue
            endpoint:@"/engage/"];
}

- (void)flushQueue:(NSMutableArray *)queue endpoint:(NSString *)endpoint
{
    if ([[NSDate date] timeIntervalSince1970] < self.networkRequestsAllowedAfterTime) {
        MixpanelDebug(@"Attempted to flush to %@, when we still have a timeout. Ignoring flush.", endpoint);
        return;
    }
    
    while ([queue count] > 0) {
        NSUInteger batchSize = ([queue count] > 50) ? 50 : [queue count];
        NSArray *batch = [queue subarrayWithRange:NSMakeRange(0, batchSize)];

        NSString *requestData = [self encodeAPIData:batch];
        NSString *postBody = [NSString stringWithFormat:@"ip=%d&data=%@", self.useIPAddressForGeoLocation, requestData];
        MixpanelDebug(@"%@ flushing %lu of %lu to %@: %@", self, (unsigned long)[batch count], (unsigned long)[queue count], endpoint, queue);
        NSURLRequest *request = [self apiRequestWithEndpoint:endpoint andBody:postBody];
        NSError *error = nil;

        [self updateNetworkActivityIndicator:YES];
        
        NSHTTPURLResponse *urlResponse = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];

        [self updateNetworkActivityIndicator:NO];
        
        BOOL success = [self handleNetworkResponse:urlResponse withError:error];
        if (error || !success) {
            MixpanelError(@"%@ network failure: %@", self, error);
            break;
        }

        NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if ([response intValue] == 0) {
            MixpanelError(@"%@ %@ api rejected some items", self, endpoint);
        }

        [queue removeObjectsInArray:batch];
    }
}

- (NSURLRequest *)apiRequestWithEndpoint:(NSString *)endpoint andBody:(NSString *)body
{
    NSURL *URL = [NSURL URLWithString:[self.serverURL stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    MixpanelDebug(@"%@ http request: %@?%@", self, URL, body);
    return request;
}

- (BOOL)handleNetworkResponse:(NSHTTPURLResponse *)response withError:(NSError *)error
{
    BOOL success = NO;
    NSTimeInterval retryTime = [response.allHeaderFields[@"Retry-After"] doubleValue];
    
    MixpanelDebug(@"HTTP Response: %@", response.allHeaderFields);
    MixpanelDebug(@"HTTP Error: %@", error.localizedDescription);
    
    BOOL was5XX = (500 <= response.statusCode && response.statusCode <= 599) || (error != nil);
    if (was5XX) {
        self.networkConsecutiveFailures++;
    } else {
        success = YES;
        self.networkConsecutiveFailures = 0;
    }
    
    MixpanelDebug(@"Consecutive network failures: %lu", self.networkConsecutiveFailures);
    
    if (self.networkConsecutiveFailures > 1) {
        // Exponential backoff
        retryTime = MAX(retryTime, [self retryBackOffTimeWithConsecutiveFailures:self.networkConsecutiveFailures]);
    }
    
    NSDate *retryDate = [NSDate dateWithTimeIntervalSinceNow:retryTime];
    self.networkRequestsAllowedAfterTime = [retryDate timeIntervalSince1970];
    
    MixpanelDebug(@"Retry backoff time: %.2f - %@", retryTime, retryDate);
    
    return success;
}

- (NSTimeInterval)retryBackOffTimeWithConsecutiveFailures:(NSUInteger)failureCount
{
    NSTimeInterval time = pow(2.0, failureCount - 1) * 60 + arc4random_uniform(30);
    return MIN(MAX(60, time), 600);
}

#pragma mark - Persistence
- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
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
    MixpanelDebug(@"%@ archiving events data to %@: %@", self, filePath, eventsQueueCopy);
    if (![NSKeyedArchiver archiveRootObject:eventsQueueCopy toFile:filePath]) {
        MixpanelError(@"%@ unable to archive events data", self);
    }
}

- (void)archivePeople
{
    NSString *filePath = [self peopleFilePath];
    NSMutableArray *peopleQueueCopy = [NSMutableArray arrayWithArray:[self.peopleQueue copy]];
    MixpanelDebug(@"%@ archiving people data to %@: %@", self, filePath, peopleQueueCopy);
    if (![NSKeyedArchiver archiveRootObject:peopleQueueCopy toFile:filePath]) {
        MixpanelError(@"%@ unable to archive people data", self);
    }
}

- (void)archiveProperties
{
    NSString *filePath = [self propertiesFilePath];
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    [p setValue:self.distinctId forKey:@"distinctId"];
    [p setValue:self.nameTag forKey:@"nameTag"];
    [p setValue:self.superProperties forKey:@"superProperties"];
    [p setValue:self.people.distinctId forKey:@"peopleDistinctId"];
    [p setValue:self.people.unidentifiedQueue forKey:@"peopleUnidentifiedQueue"];
    [p setValue:self.shownSurveyCollections forKey:@"shownSurveyCollections"];
    [p setValue:self.shownNotifications forKey:@"shownNotifications"];
    [p setValue:self.timedEvents forKey:@"timedEvents"];
    MixpanelDebug(@"%@ archiving properties data to %@: %@", self, filePath, p);
    if (![NSKeyedArchiver archiveRootObject:p toFile:filePath]) {
        MixpanelError(@"%@ unable to archive properties data", self);
    }
}

- (void)archiveVariants
{
    NSString *filePath = [self variantsFilePath];
    if (![NSKeyedArchiver archiveRootObject:self.variants toFile:filePath]) {
        MixpanelError(@"%@ unable to archive variants data", self);
    }
}

- (void)archiveEventBindings
{
    NSString *filePath = [self eventBindingsFilePath];
    if (![NSKeyedArchiver archiveRootObject:self.eventBindings toFile:filePath]) {
        MixpanelError(@"%@ unable to archive tracking events data", self);
    }
}

- (void)unarchive
{
    [self unarchiveEvents];
    [self unarchivePeople];
    [self unarchiveProperties];
    [self unarchiveVariants];
    [self unarchiveEventBindings];
}

- (id)unarchiveFromFile:(NSString *)filePath
{
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        MixpanelDebug(@"%@ unarchived data from %@: %@", self, filePath, unarchivedData);
    }
    @catch (NSException *exception) {
        MixpanelError(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        // Reset un archived data
        unarchivedData = nil;
        // Remove the (possibly) corrupt data from the disk
        NSError *error = NULL;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (!removed) {
            MixpanelError(@"%@ unable to remove archived file at %@ - %@", self, filePath, error);
        }
    }
    return unarchivedData;
}

- (void)unarchiveEvents
{
    self.eventsQueue = (NSMutableArray *)[self unarchiveFromFile:[self eventsFilePath]];
    if (!self.eventsQueue) {
        self.eventsQueue = [NSMutableArray array];
    }
}

- (void)unarchivePeople
{
    self.peopleQueue = (NSMutableArray *)[self unarchiveFromFile:[self peopleFilePath]];
    if (!self.peopleQueue) {
        self.peopleQueue = [NSMutableArray array];
    }
}

- (void)unarchiveProperties
{
    NSDictionary *properties = (NSDictionary *)[self unarchiveFromFile:[self propertiesFilePath]];
    if (properties) {
        self.distinctId = properties[@"distinctId"] ? properties[@"distinctId"] : [self defaultDistinctId];
        self.nameTag = properties[@"nameTag"];
        self.superProperties = properties[@"superProperties"] ? properties[@"superProperties"] : [NSMutableDictionary dictionary];
        self.people.distinctId = properties[@"peopleDistinctId"];
        self.people.unidentifiedQueue = properties[@"peopleUnidentifiedQueue"] ? properties[@"peopleUnidentifiedQueue"] : [NSMutableArray array];
        self.shownSurveyCollections = properties[@"shownSurveyCollections"] ? properties[@"shownSurveyCollections"] : [NSMutableSet set];
        self.shownNotifications = properties[@"shownNotifications"] ? properties[@"shownNotifications"] : [NSMutableSet set];
        self.variants = properties[@"variants"] ? properties[@"variants"] : [NSSet set];
        self.eventBindings = properties[@"event_bindings"] ? properties[@"event_bindings"] : [NSSet set];
        self.timedEvents = properties[@"timedEvents"] ? properties[@"timedEvents"] : [NSMutableDictionary dictionary];
    }
}

- (void)unarchiveVariants
{
    self.variants = (NSSet *)[self unarchiveFromFile:[self variantsFilePath]];
    if (!self.variants) {
        self.variants = [NSSet set];
    }
}

- (void)unarchiveEventBindings
{
    self.eventBindings = (NSSet *)[self unarchiveFromFile:[self eventBindingsFilePath]];
    if (!self.eventBindings || ![self.eventBindings isKindOfClass:[NSSet class]]) {
        self.eventBindings = [NSSet set];
    }
}

#pragma mark - Application Helpers

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Mixpanel: %p %@>", (void *)self, self.apiToken];
}

- (NSString *)deviceModel
{
    NSString *results = nil;
    @try {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char answer[size];
        sysctlbyname("hw.machine", answer, &size, NULL, 0);
        results = @(answer);
    }
    @catch (NSException *exception) {
        MixpanelError(@"Failed fetch hw.machine from sysctl. Details: %@", exception);
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
            if (screenBounds.size.width == 136.0f){
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
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        ifa = [uuid UUIDString];
    }
#endif
    return ifa;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
- (void)setCurrentRadio
{
    dispatch_async(self.serialQueue, ^(){
        NSMutableDictionary *properties = [self.automaticProperties mutableCopy];
        if (properties) {
            properties[@"$radio"] = [self currentRadio];
            self.automaticProperties = [properties copy];
        }
    });
}

- (NSString *)currentRadio
{
#if !defined(MIXPANEL_APP_EXTENSION)
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
#endif

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
    
#if !defined(MIXPANEL_APP_EXTENSION)
    CTCarrier *carrier = [self.telephonyInfo subscriberCellularProvider];
    [p setValue:carrier.carrierName forKey:@"$carrier"];
#endif
    
    [p setValue:[self watchModel] forKey:@"$watch_model"];

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

- (void)updateNetworkActivityIndicator:(BOOL)on
{
#if !defined(MIXPANEL_APP_EXTENSION)
    if (_showNetworkActivityIndicator) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = on;
    }
#endif
}

#if !defined(MIXPANEL_APP_EXTENSION)

#pragma mark - UIApplication Events

- (void)setUpListeners
{
    // wifi reachability
    BOOL reachabilityOk = NO;
    if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "api.mixpanel.com")) != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(_reachability, MixpanelReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(_reachability, self.serialQueue)) {
                reachabilityOk = YES;
                MixpanelDebug(@"%@ successfully set up reachability callback", self);
            } else {
                // cleanup callback if setting dispatch queue failed
                SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
            }
        }
    }
    if (!reachabilityOk) {
        MixpanelError(@"%@ failed to set up reachability callback: %s", self, SCErrorString(SCError()));
    }

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    // cellular info
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0) {
        [self setCurrentRadio];
        [notificationCenter addObserver:self
                               selector:@selector(setCurrentRadio)
                                   name:CTRadioAccessTechnologyDidChangeNotification
                                 object:nil];
    }
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

#if !defined(DISABLE_MIXPANEL_AB_DESIGNER)
    dispatch_async(dispatch_get_main_queue(), ^{
        UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(connectGestureRecognized:)];
        recognizer.minimumPressDuration = 3;
        recognizer.cancelsTouchesInView = NO;
#if TARGET_IPHONE_SIMULATOR
        recognizer.numberOfTouchesRequired = 2;
#else
        recognizer.numberOfTouchesRequired = 4;
#endif
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:recognizer];
    });
#endif
}

static void MixpanelReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    Mixpanel *mixpanel = (__bridge Mixpanel *)info;
    if (mixpanel && [mixpanel isKindOfClass:[Mixpanel class]]) {
        [mixpanel reachabilityChanged:flags];
    } else {
        MixpanelError(@"reachability callback received unexpected info object");
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
        properties[@"$wifi"] = wifi ? @YES : @NO;
        self.automaticProperties = [properties copy];
        MixpanelDebug(@"%@ reachability changed, wifi=%d", self, wifi);
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application did become active", self);
    [self startFlushTimer];

    if (self.checkForSurveysOnActive || self.checkForNotificationsOnActive || self.checkForVariantsOnActive) {
        NSDate *start = [NSDate date];

        [self checkForDecideResponseWithCompletion:^(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings) {
            if (self.showNotificationOnActive && notifications && [notifications count] > 0) {
                [self showNotificationWithObject:notifications[0]];
            } else if (self.showSurveyOnActive && surveys && [surveys count] > 0) {
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
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application will resign active", self);
    [self stopFlushTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    MixpanelDebug(@"%@ did enter background", self);

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        MixpanelDebug(@"%@ flush %lu cut short", self, (unsigned long) backgroundTask);
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        self.taskId = UIBackgroundTaskInvalid;
    }];
    self.taskId = backgroundTask;
    MixpanelDebug(@"%@ starting background cleanup task %lu", self, (unsigned long)self.taskId);

    if (self.flushOnBackground) {
        [self flush];
    }

    dispatch_async(_serialQueue, ^{
        [self archive];
        MixpanelDebug(@"%@ ending background cleanup task %lu", self, (unsigned long)self.taskId);
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
        self.decideResponseCached = NO;
    });
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification
{
    MixpanelDebug(@"%@ will enter foreground", self);
    dispatch_async(self.serialQueue, ^{
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
            [self updateNetworkActivityIndicator:NO];
        }
    });
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application will terminate", self);
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
    NSDictionary *userInfo = [notification userInfo];
    if (userInfo && userInfo[@"event_name"] && userInfo[@"event_args"] && eventMap[userInfo[@"event_name"]]) {
        [self track:eventMap[userInfo[@"event_name"]] properties:userInfo[@"event_args"]];
    }
}

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

    Class UIAlertControllerClass = NSClassFromString(@"UIAlertController");
    if (UIAlertControllerClass && [viewController isKindOfClass:UIAlertControllerClass]) {
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
        MixpanelDebug(@"%@ decide check started", self);

        NSMutableSet *newVariants = [NSMutableSet set];
        NSMutableSet *newEventBindings = [NSMutableSet set];

        if (!useCache || !self.decideResponseCached) {
            MixpanelDebug(@"%@ decide cache not found, starting network request", self);
            NSString *distinctId = self.people.distinctId ? self.people.distinctId : self.distinctId;
            NSData *peoplePropertiesJSON = [NSJSONSerialization dataWithJSONObject:self.people.automaticPeopleProperties options:(NSJSONWritingOptions)0 error:nil];
            NSString *params = [NSString stringWithFormat:@"version=1&lib=iphone&token=%@&properties=%@%@",
                                self.apiToken,
                                MPURLEncode([[NSString alloc] initWithData:peoplePropertiesJSON encoding:NSUTF8StringEncoding]),
                                (distinctId ? [NSString stringWithFormat:@"&distinct_id=%@", MPURLEncode(distinctId)] : @"")
                                ];
            NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/decide?%@", self.decideURL, params]];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
            [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
            NSError *error = nil;
            NSURLResponse *urlResponse = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
            if (error) {
                MixpanelError(@"%@ decide check http error: %@", self, error);
                if (completion) {
                    completion(nil, nil, nil, nil);
                }
                return;
            }
            NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:&error];
            if (error) {
                MixpanelError(@"%@ decide check json error: %@, data: %@", self, error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                if (completion) {
                    completion(nil, nil, nil, nil);
                }
                return;
            }
            if (object[@"error"]) {
                MixpanelDebug(@"%@ decide check api error: %@", self, object[@"error"]);
                if (completion) {
                    completion(nil, nil, nil, nil);
                }
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

            NSArray *rawSurveys = object[@"surveys"];
            NSMutableArray *parsedSurveys = [NSMutableArray array];
            if (rawSurveys && [rawSurveys isKindOfClass:[NSArray class]]) {
                for (id obj in rawSurveys) {
                    MPSurvey *survey = [MPSurvey surveyWithJSONObject:obj];
                    if (survey) {
                        [parsedSurveys addObject:survey];
                    }
                }
            } else {
               MixpanelDebug(@"%@ survey check response format error: %@", self, object);
            }

            NSArray *rawNotifications = object[@"notifications"];
            NSMutableArray *parsedNotifications = [NSMutableArray array];
            if (rawNotifications && [rawNotifications isKindOfClass:[NSArray class]]) {
                for (id obj in rawNotifications) {
                    MPNotification *notification = [MPNotification notificationWithJSONObject:obj];
                    if (notification) {
                        [parsedNotifications addObject:notification];
                    }
                }
            } else {
                MixpanelDebug(@"%@ in-app notifs check response format error: %@", self, object);
            }

            NSArray *rawVariants = object[@"variants"];
            NSMutableSet *parsedVariants = [NSMutableSet set];
            if (rawVariants && [rawVariants isKindOfClass:[NSArray class]]) {
                for (id obj in rawVariants) {
                    MPVariant *variant = [MPVariant variantWithJSONObject:obj];
                    if (variant) {
                        [parsedVariants addObject:variant];
                    }
                }
            } else {
                MixpanelDebug(@"%@ variants check response format error: %@", self, object);
            }

            // Variants that are already running (may or may not have been marked as finished).
            NSSet *runningVariants = [NSSet setWithSet:[self.variants objectsPassingTest:^BOOL(MPVariant *var, BOOL *stop) { return var.running; }]];
            // Variants that are marked as finished, (may or may not be running still).
            NSSet *finishedVariants = [NSSet setWithSet:[self.variants objectsPassingTest:^BOOL(MPVariant *var, BOOL *stop) { return var.finished; }]];
            // Variants that are running that should be marked finished.
            NSMutableSet *toFinishVariants = [NSMutableSet setWithSet:runningVariants];
            [toFinishVariants minusSet:parsedVariants];
            // New variants that we just saw that are not already running.
            newVariants = [NSMutableSet setWithSet:parsedVariants];
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

            NSArray *rawEventBindings = object[@"event_bindings"];
            NSMutableSet *parsedEventBindings = [NSMutableSet set];
            if (rawEventBindings && [rawEventBindings isKindOfClass:[NSArray class]]) {
                for (id obj in rawEventBindings) {
                    MPEventBinding *binder = [MPEventBinding bindingWithJSONObject:obj];
                    [binder execute];
                    if (binder) {
                        [parsedEventBindings addObject:binder];
                    }
                }
            } else {
                MixpanelDebug(@"%@ mp tracking events check response format error: %@", self, object);
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
        } else {
            MixpanelDebug(@"%@ decide cache found, skipping network request", self);
        }

        NSArray *unseenSurveys = [self.surveys objectsAtIndexes:[self.surveys indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop){
            return [self.shownSurveyCollections member:@(((MPSurvey *)obj).collectionID)] == nil;
        }]];

        NSArray *unseenNotifications = [self.notifications objectsAtIndexes:[self.notifications indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [self.shownNotifications member:@(((MPNotification *)obj).ID)] == nil;
        }]];

        MixpanelDebug(@"%@ decide check found %lu available surveys out of %lu total: %@", self, (unsigned long)[unseenSurveys count], (unsigned long)[self.surveys count], unseenSurveys);
        MixpanelDebug(@"%@ decide check found %lu available notifs out of %lu total: %@", self, (unsigned long)[unseenNotifications count],
                      (unsigned long)[self.notifications count], unseenNotifications);
        MixpanelDebug(@"%@ decide check found %lu variants: %@", self, (unsigned long)[self.variants count], self.variants);
        MixpanelDebug(@"%@ decide check found %lu tracking events: %@", self, (unsigned long)[self.eventBindings count], self.eventBindings);

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
#if !defined(MIXPANEL_APP_EXTENSION)
    UIViewController *presentingViewController = [Mixpanel topPresentedViewController];

    if ([[self class] canPresentFromViewController:presentingViewController]) {
        UIStoryboard *storyboard = [MPResources surveyStoryboard];
        MPSurveyNavigationController *controller = [storyboard instantiateViewControllerWithIdentifier:@"MPSurveyNavigationController"];
        controller.survey = survey;
        controller.delegate = self;
        controller.backgroundImage = [presentingViewController.view mp_snapshotImage];
        [presentingViewController presentViewController:controller animated:YES completion:nil];
    }
#endif
}

- (void)showSurveyWithObject:(MPSurvey *)survey withAlert:(BOOL)showAlert
{
    if (survey) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentlyShowingSurvey) {
                MixpanelError(@"%@ already showing survey: %@", self, self.currentlyShowingSurvey);
            } else if (self.currentlyShowingNotification) {
                MixpanelError(@"%@ already showing in-app notification: %@", self, self.currentlyShowingNotification);
            } else {
                self.currentlyShowingSurvey = survey;
                if (showAlert) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
                    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0) {
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
                    } else
#endif
                    {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"We'd love your feedback!"
                                                                        message:@"Mind taking a quick survey?"
                                                                       delegate:self
                                                              cancelButtonTitle:@"No, Thanks"
                                                              otherButtonTitles:@"Sure", nil];
                        [alert show];
                    }
                } else {
                    [self presentSurveyWithRootViewController:survey];
                }
            }
        });
    } else {
        MixpanelError(@"%@ cannot show nil survey", self);
    }
}

- (void)showSurveyWithObject:(MPSurvey *)survey
{
    [self showSurveyWithObject:survey withAlert:NO];
}

- (void)showSurvey
{
    [self checkForSurveysWithCompletion:^(NSArray *surveys){
        if ([surveys count] > 0) {
            [self showSurveyWithObject:surveys[0]];
        }
    }];
}

- (void)showSurveyWithID:(NSUInteger)ID
{
    [self checkForSurveysWithCompletion:^(NSArray *surveys){
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
    MixpanelDebug(@"%@ marking survey shown: %@, %@", self, @(survey.collectionID), _shownSurveyCollections);
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
        MixpanelDebug(@"%@ not sending survey %@ result", self, controller.survey);
    } else {
        [self markSurvey:controller.survey shown:YES withAnswerCount:[answers count]];
        for (NSUInteger i = 0, n = [answers count]; i < n; i++) {
            if (i == 0) {
                [self.people append:@{@"$answers": answers[i], @"$responses": @(controller.survey.collectionID)}];
            } else {
                [self.people append:@{@"$answers": answers[i]}];
            }
        }
        
        dispatch_async(_serialQueue, ^{
            [self flushPeople];
        });
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (_currentlyShowingSurvey) {
        if (buttonIndex == 1) {
            [self presentSurveyWithRootViewController:_currentlyShowingSurvey];
        } else {
            [self markSurvey:_currentlyShowingSurvey shown:NO withAnswerCount:0];
            self.currentlyShowingSurvey = nil;
        }
    }
}

#pragma mark - Mixpanel Notifications

- (void)showNotification
{
    [self checkForNotificationsWithCompletion:^(NSArray *notifications) {
        if ([notifications count] > 0) {
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
            MixpanelError(@"%@ already showing in-app notification: %@", self, self.currentlyShowingNotification);
        } else if (self.currentlyShowingSurvey) {
            MixpanelError(@"%@ already showing survey: %@", self, self.currentlyShowingSurvey);
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
#if !defined(MIXPANEL_APP_EXTENSION)
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
#endif
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
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self notificationController:controller wasDismissedWithStatus:NO];
    });
    return YES;
}

- (void)notificationController:(MPNotificationViewController *)controller wasDismissedWithStatus:(BOOL)status
{
    if (controller == nil || self.currentlyShowingNotification != controller.notification) {
        return;
    }

    void (^completionBlock)()  = ^void(){
        self.currentlyShowingNotification = nil;
        self.notificationViewController = nil;
    };

    if (status && controller.notification.callToActionURL) {
        [controller hideWithAnimation:YES completion:^{
            NSURL *URL = controller.notification.callToActionURL;
            MixpanelDebug(@"%@ opening URL %@", self, URL);

            if (![[UIApplication sharedApplication] openURL:URL]) {
                MixpanelError(@"Mixpanel failed to open given URL: %@", URL);
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
        MixpanelDebug(@"%@ ignoring notif track for %@, %@", self, @(notification.ID), event);
    }
}

- (void)markNotificationShown:(MPNotification *)notification
{
    MixpanelDebug(@"%@ marking notification shown: %@, %@", self, @(notification.ID), _shownNotifications);

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

#pragma mark - Mixpanel A/B Testing (Designer)

- (void)connectGestureRecognized:(id)sender
{
    if(!sender || ([sender isKindOfClass:[UIGestureRecognizer class]] && ((UIGestureRecognizer *)sender).state == UIGestureRecognizerStateBegan )) {
        [self connectToABTestDesigner];
    }
}

- (void)connectToABTestDesigner
{
    [self connectToABTestDesigner:NO];
}

- (void)connectToABTestDesigner:(BOOL)reconnect
{
    if ([self.abtestDesignerConnection isKindOfClass:[MPABTestDesignerConnection class]] && ((MPABTestDesignerConnection *)self.abtestDesignerConnection).connected) {
        MixpanelError(@"A/B test designer connection already exists");
    } else {
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
    MixpanelDebug(@"%@ marking variant %@ shown for experiment %@", self, @(variant.ID), @(variant.experimentID));
    NSDictionary *shownVariant = @{[@(variant.experimentID) stringValue]: @(variant.ID)};
    if (self.people.distinctId) {
        [self.people merge:@{@"$experiments": shownVariant}];
    }

    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *superProperties = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        NSMutableDictionary *shownVariants = [NSMutableDictionary dictionaryWithDictionary: superProperties[@"$experiments"]];
        [shownVariants addEntriesFromDictionary:shownVariant];
        [superProperties addEntriesFromDictionary:@{@"$experiments": [shownVariants copy]}];
        self.superProperties = [superProperties copy];
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    });

    [self track:@"$experiment_started" properties:@{@"$experiment_id" : @(variant.experimentID), @"$variant_id": @(variant.ID)}];
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

#endif

@end

#pragma mark - People
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
    __strong Mixpanel *strongMixpanel = _mixpanel;
    return [NSString stringWithFormat:@"<MixpanelPeople: %p %@>", (void *)self, (strongMixpanel ? strongMixpanel.apiToken : @"")];
}

- (NSDictionary *)collectAutomaticPeopleProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    __strong Mixpanel *strongMixpanel = _mixpanel;
    [p setValue:[strongMixpanel deviceModel] forKey:@"$ios_device_model"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:@"$ios_app_version"];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$ios_app_release"];
    [p setValue:[strongMixpanel IFA] forKey:@"$ios_ifa"];
    [p addEntriesFromDictionary:@{@"$ios_version": [[UIDevice currentDevice] systemVersion],
                                 @"$ios_lib_version": VERSION,
                                  }];
    return [p copy];
}

- (void)addPeopleRecordToQueueWithAction:(NSString *)action andProperties:(NSDictionary *)properties
{
    NSNumber *epochMilliseconds = @(round([[NSDate date] timeIntervalSince1970] * 1000));
    __strong Mixpanel *strongMixpanel = _mixpanel;
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
                MixpanelDebug(@"%@ queueing people record: %@", self.mixpanel, r);
                [strongMixpanel.peopleQueue addObject:r];
                if ([strongMixpanel.peopleQueue count] > 500) {
                    [strongMixpanel.peopleQueue removeObjectAtIndex:0];
                }
            } else {
                MixpanelDebug(@"%@ queueing unidentified people record: %@", self.mixpanel, r);
                [self.unidentifiedQueue addObject:r];
                if ([self.unidentifiedQueue count] > 500) {
                    [self.unidentifiedQueue removeObjectAtIndex:0];
                }
            }
            
            [strongMixpanel archivePeople];
        });
#if defined(MIXPANEL_APP_EXTENSION)
        [strongMixpanel flush];
#endif
    }
}

#pragma mark - Public API

- (void)addPushDeviceToken:(NSData *)deviceToken
{
    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    NSArray *tokens = @[[NSString stringWithString:hex]];
    NSDictionary *properties = @{@"$ios_devices": tokens};
    [self addPeopleRecordToQueueWithAction:@"$union" andProperties:properties];
}

- (void)removePushDeviceToken
{
    NSDictionary *properties = @{ @"$properties": @[@"$ios_devices"] };
    [self addPeopleRecordToQueueWithAction:@"$unset" andProperties:properties];
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
    [self addPeopleRecordToQueueWithAction:@"$unset" andProperties:@{@"$properties":properties}];
}

- (void)increment:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    for (id __unused v in [properties allValues]) {
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
    for (id __unused v in [properties allValues]) {
        NSAssert([v isKindOfClass:[NSArray class]],
                 @"%@ union property values should be NSArray. found: %@", self, v);
    }
    [self addPeopleRecordToQueueWithAction:@"$union" andProperties:properties];
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
