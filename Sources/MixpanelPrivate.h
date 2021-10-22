//
//  MixpanelPrivate.h
//  Mixpanel
//
//  Created by Sam Green on 6/16/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MPNetwork.h"
#import "SessionMetadata.h"
#import "MixpanelType.h"

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
static NSString *const kPersistenceTypeEvents = @"events";
static NSString *const kPersistenceTypePeople = @"people";
static NSString *const kPersistenceTypeGroups = @"groups";


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

#if !defined(MIXPANEL_WATCHOS) && !defined(MIXPANEL_MACOS)
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskId;
#endif

// re-declare internally as readwrite
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
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSMutableArray *peopleQueue;
@property (nonatomic, strong) NSMutableArray *groupsQueue;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic) dispatch_queue_t networkQueue;
@property (nonatomic) dispatch_queue_t archiveQueue;
@property (nonatomic, strong) NSMutableDictionary *timedEvents;
@property (nonatomic, strong) SessionMetadata *sessionMetadata;

@property (nonatomic) BOOL decideResponseCached;
@property (nonatomic, strong) NSNumber *automaticEventsEnabled;


@property (nonatomic, assign) BOOL optOutStatus;
@property (nonatomic, assign) BOOL optOutStatusNotSet;

@property (nonatomic, strong) NSString *savedUrbanAirshipChannelID;

+ (void)assertPropertyTypes:(NSDictionary *)properties;

+ (BOOL)isAppExtension;
#if !MIXPANEL_NO_UIAPPLICATION_ACCESS
+ (UIApplication *)sharedUIApplication;
#endif

- (NSString *)deviceModel;

- (void)archivePeople;
- (NSString *)defaultDistinctId;
- (void)archive;
- (NSString *)eventsFilePath;
- (NSString *)peopleFilePath;
- (NSString *)groupsFilePath;
- (NSString *)propertiesFilePath;
- (NSString *)optOutFilePath;

// for group caching
- (NSString *)keyForGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

@end
