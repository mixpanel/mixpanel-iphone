//
//  MixpanelPrivate.h
//  Mixpanel
//
//  Created by Sam Green on 6/16/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MPNetwork.h"

#if !MIXPANEL_NO_EXCEPTION_HANDLING
#import "MixpanelExceptionHandler.h"
#endif

#if TARGET_OS_IPHONE
#if !MIXPANEL_NO_REACHABILITY_SUPPORT
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>
#endif

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
#import "Mixpanel+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"
#endif
#endif

#if !MIXPANEL_NO_SURVEY_NOTIFICATION_AB_TEST_SUPPORT
#import "MPResources.h"
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

#if !MIXPANEL_NO_SURVEY_NOTIFICATION_AB_TEST_SUPPORT
@interface Mixpanel () <MPSurveyNavigationControllerDelegate, MPNotificationViewControllerDelegate>
#else
@interface Mixpanel ()
#endif
{
    NSUInteger _flushInterval;
    BOOL _enableVisualABTestAndCodeless;
}

#if !MIXPANEL_NO_REACHABILITY_SUPPORT
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
#endif

#if !MIXPANEL_NO_SURVEY_NOTIFICATION_AB_TEST_SUPPORT
@property (nonatomic, strong) UILongPressGestureRecognizer *testDesignerGestureRecognizer;
@property (nonatomic, strong) MPABTestDesignerConnection *abtestDesignerConnection;
#endif

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
@property (nonatomic) AutomaticEventMode validationMode;
@property (nonatomic) NSUInteger validationEventCount;
@property (nonatomic, getter=isValidationEnabled) BOOL validationEnabled;
#endif

#if !defined(MIXPANEL_WATCH_EXTENSION)
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskId;
@property (nonatomic, strong) UIViewController *notificationViewController;
#endif

// re-declare internally as readwrite
@property (atomic, strong) MixpanelPeople *people;
@property (atomic, strong) MPNetwork *network;
@property (atomic, copy) NSString *distinctId;

@property (nonatomic, copy) NSString *apiToken;
@property (atomic, strong) NSDictionary *superProperties;
@property (atomic, strong) NSDictionary *automaticProperties;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSMutableArray *peopleQueue;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableDictionary *timedEvents;

@property (nonatomic) BOOL decideResponseCached;
@property (nonatomic, strong) NSArray *surveys;
@property (nonatomic, strong) id currentlyShowingSurvey;
@property (nonatomic, strong) NSMutableSet *shownSurveyCollections;

@property (nonatomic, strong) NSArray *notifications;
@property (nonatomic, strong) id currentlyShowingNotification;
@property (nonatomic, strong) NSMutableSet *shownNotifications;

@property (nonatomic, strong) NSSet *variants;
@property (nonatomic, strong) NSSet *eventBindings;

@property (atomic, copy) NSString *switchboardURL;

+ (void)assertPropertyTypes:(NSDictionary *)properties;

- (NSString *)deviceModel;
- (NSString *)IFA;

- (void)archivePeople;
- (NSString *)defaultDistinctId;
- (void)archive;
- (NSString *)eventsFilePath;
- (NSString *)peopleFilePath;
- (NSString *)propertiesFilePath;

#if !MIXPANEL_NO_SURVEY_NOTIFICATION_AB_TEST_SUPPORT
- (void)presentSurveyWithRootViewController:(MPSurvey *)survey;
- (void)showNotificationWithObject:(MPNotification *)notification;
- (void)markVariantRun:(MPVariant *)variant;
- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion;
- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion useCache:(BOOL)useCache;
#endif

@end

