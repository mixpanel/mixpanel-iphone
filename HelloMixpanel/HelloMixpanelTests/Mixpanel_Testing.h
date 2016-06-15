//
//  Mixpanel_Testing.h
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Nocilla/Nocilla.h>
#import "Mixpanel.h"
#import "MPVariant.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"

#pragma mark - Constants
static NSString *const kTestToken = @"abc123";
static NSString *const kDefaultServerString = @"https://api.mixpanel.com";
static NSString *const kDefaultServerTrackString = @"https://api.mixpanel.com/track/";
static NSString *const kDefaultServerEngageString = @"https://api.mixpanel.com/engage/";

#pragma mark - Stub Helpers
static inline LSStubRequestDSL *stubEngage() {
    return stubRequest(@"POST", kDefaultServerEngageString).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubTrack() {
    return stubRequest(@"POST", kDefaultServerTrackString).withHeader(@"Accept-Encoding", @"gzip");
}

#pragma mark - Test Interfaces
@interface Mixpanel (Test)

@property (nonatomic, assign) dispatch_queue_t serialQueue;

@property (atomic, copy) NSString *decideURL;
@property (nonatomic, strong) NSSet *variants;
@property (nonatomic, retain) NSMutableArray *eventsQueue;
@property (atomic, strong) NSDictionary *superProperties;

@property (nonatomic, retain) NSMutableArray *peopleQueue;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, retain) NSMutableDictionary *timedEvents;

@property (nonatomic, strong) MPSurvey *currentlyShowingSurvey;
@property (nonatomic, strong) MPNotification *currentlyShowingNotification;
@property (nonatomic, strong) MPNotificationViewController *notificationViewController;
@property (nonatomic) NSTimeInterval networkRequestsAllowedAfterTime;
@property (nonatomic) NSUInteger networkConsecutiveFailures;

- (NSString *)defaultDistinctId;
- (void)archive;
- (NSString *)eventsFilePath;
- (NSString *)peopleFilePath;
- (NSString *)propertiesFilePath;
- (void)presentSurveyWithRootViewController:(MPSurvey *)survey;
- (void)showNotificationWithObject:(MPNotification *)notification;

- (NSData *)JSONSerializeObject:(id)obj;
- (NSString *)encodeAPIData:(NSArray *)array;

- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion;
- (void)checkForDecideResponseWithCompletion:(void (^)(NSArray *surveys, NSArray *notifications, NSSet *variants, NSSet *eventBindings))completion useCache:(BOOL)useCache;
- (void)markVariantRun:(MPVariant *)variant;

@end

@interface MixpanelPeople (Test)

@property (nonatomic, retain) NSMutableArray *unidentifiedQueue;
@property (nonatomic, copy) NSMutableArray *distinctId;

@end

@interface MPVariantAction (Test)

+ (BOOL)executeSelector:(SEL)selector
               withArgs:(NSArray *)args
              onObjects:(NSArray *)objects;

@end
