//
//  MixpanelPrivate.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MPNetwork.h"
#import "SessionMetadata.h"
#import "MixpanelType.h"
#import "MixpanelPersistence.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>
#endif

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
#import "AutomaticEvents.h"
#import "MixpanelExceptionHandler.h"
#endif


// Persistence constants used internally
static NSString *const PersistenceTypeEvents = @"events";
static NSString *const PersistenceTypePeople = @"people";
static NSString *const PersistenceTypeGroups = @"groups";

static BOOL UnIdentifiedFlag = YES;
static BOOL IdentifiedFlag = NO;

// Internal Standard UserDefaults Keys
static NSString *const MPDebugTrackedKey = @"MPDebugTrackedKey";
static NSString *const MPDebugInitCountKey = @"MPDebugInitCountKey";
static NSString *const MPDebugImplementedKey = @"MPDebugImplementedKey";
static NSString *const MPDebugIdentifiedKey = @"MPDebugIdentifiedKey";
static NSString *const MPDebugAliasedKey = @"MPDebugAliasedKey";
static NSString *const MPDebugUsedPeopleKey = @"MPDebugUsedPeopleKey";

#if defined(MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT)
@interface Mixpanel ()
#else
@interface Mixpanel () <TrackDelegate>
#endif

{
    NSUInteger _flushInterval;
}

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
#endif


#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
@property (atomic, strong) AutomaticEvents *automaticEvents;
#endif

#if !TARGET_OS_WATCH && !TARGET_OS_OSX
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskId;
#endif

// re-declare internally as readwrite
@property (atomic, strong) MixpanelPersistence *persistence;
@property (atomic, strong) MixpanelPeople *people;
@property (atomic, strong) NSMutableDictionary<NSString*, MixpanelGroup*> * cachedGroups;
@property (atomic, strong) MPNetwork *network;
@property (atomic, copy) NSString *distinctId;
@property (atomic, copy) NSString *alias;
@property (atomic, copy) NSString *anonymousId;
@property (atomic, copy) NSString *userId;

@property (nonatomic, copy) NSString *apiToken;
@property (atomic, strong) NSDictionary *superProperties;
@property (atomic, strong) NSDictionary *automaticProperties;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic) dispatch_queue_t networkQueue;
@property (nonatomic, strong) NSMutableDictionary *timedEvents;
@property (nonatomic, strong) SessionMetadata *sessionMetadata;

@property (nonatomic) BOOL decideResponseCached;


@property (nonatomic, assign) BOOL optOutStatus;
@property (nonatomic, assign) BOOL optOutStatusNotSet;

@property (nonatomic, strong) NSString *savedUrbanAirshipChannelID;

+ (void)assertPropertyTypes:(NSDictionary *)properties;

+ (BOOL)isAppExtension;
#if !MIXPANEL_NO_UIAPPLICATION_ACCESS
+ (UIApplication *)sharedUIApplication;
#endif

- (NSString *)deviceModel;

- (NSString *)defaultDistinctId;
- (void)archive;

// for group caching
- (NSString *)keyForGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

@end
