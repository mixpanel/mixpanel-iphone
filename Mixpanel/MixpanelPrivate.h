//
//  MixpanelPrivate.h
//  Mixpanel
//
//  Created by Sam Green on 6/16/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MPSurveyNavigationController.h"
#import "MPNotificationViewController.h"

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
#import "Mixpanel+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"

#endif

#if !defined(MIXPANEL_APP_EXTENSION)
@interface Mixpanel () <MPSurveyNavigationControllerDelegate, MPNotificationViewControllerDelegate>
#else
@interface Mixpanel ()
#endif
{
    NSUInteger _flushInterval;
    BOOL _enableABTestDesigner;
}

#if !defined(MIXPANEL_APP_EXTENSION)
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) UILongPressGestureRecognizer *testDesignerGestureRecognizer;
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

@property (nonatomic, strong) MPABTestDesignerConnection *abtestDesignerConnection;
@property (nonatomic, strong) NSSet *variants;
@property (nonatomic, strong) NSSet *eventBindings;

@property (atomic, copy) NSString *decideURL;
@property (atomic, copy) NSString *switchboardURL;
@property (nonatomic) NSTimeInterval networkRequestsAllowedAfterTime;
@property (nonatomic) NSUInteger networkConsecutiveFailures;

+ (void)assertPropertyTypes:(NSDictionary *)properties;

- (NSString *)deviceModel;
- (NSString *)IFA;

- (void)archivePeople;

@end