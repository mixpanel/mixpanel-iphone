#import <XCTest/XCTest.h>

#import <objc/runtime.h>
#import "HTTPServer.h"
#import "Mixpanel.h"
#import "MixpanelDummyHTTPConnection.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"
#import "MPSurvey.h"
#import "MPSurveyNavigationController.h"
#import "MPSurveyQuestion.h"

#define TEST_TOKEN @"abc123"

#pragma mark - Interface Redefinitions

@interface Mixpanel (Test)

// get access to private members

@property (nonatomic, retain) NSMutableArray *eventsQueue;
@property (nonatomic, retain) NSMutableArray *peopleQueue;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, assign) dispatch_queue_t serialQueue;
@property (nonatomic, retain) NSMutableDictionary *timedEvents;

@property (nonatomic, strong) MPSurvey *currentlyShowingSurvey;
@property (nonatomic, strong) MPNotification *currentlyShowingNotification;
@property (nonatomic, strong) MPNotificationViewController *notificationViewController;

- (NSString *)defaultDistinctId;
- (void)archive;
- (NSString *)eventsFilePath;
- (NSString *)peopleFilePath;
- (NSString *)propertiesFilePath;
- (void)presentSurveyWithRootViewController:(MPSurvey *)survey;
- (void)showNotificationWithObject:(MPNotification *)notification;

- (NSData *)JSONSerializeObject:(id)obj;
- (NSString *)encodeAPIData:(NSArray *)array;

@end

@interface MixpanelPeople (Test)

// get access to private members

@property (nonatomic, retain) NSMutableArray *unidentifiedQueue;
@property (nonatomic, copy) NSMutableArray *distinctId;

@end

/*
 This is to let the tests run in XCode 5, as the XCode 5
 version of XCTest does not support asynchonous tests and
 will not compile unless we define these symbols.
 */
#if !__has_include("XCTest/XCTestCase+AsynchronousTesting.h")
@interface XCTestExpectation

- (void)fulfill;

@end

@interface XCTestCase (Test)

- (void)waitForExpectationsWithTimeout:(NSTimeInterval)timeout handler:(id)handlerOrNil;
- (XCTestExpectation *)expectationWithDescription:(NSString *)description;

@end
#endif

@interface HelloMixpanelTests : XCTestCase  <MixpanelDelegate>

@property (nonatomic, strong) Mixpanel *mixpanel;
@property (nonatomic, strong) HTTPServer *httpServer;
@property (atomic) BOOL mixpanelWillFlush;

@end

@implementation NSLocale (OverrideLocale)

+ (void)load
{
    method_exchangeImplementations(class_getClassMethod(self, @selector(currentLocale)), class_getClassMethod(self, @selector(swz_currentLocale)));
}

+ (id)swz_currentLocale
{
    return [NSLocale localeWithLocaleIdentifier:@"en_US@calendar=hebrew"];
}

@end

#pragma mark - Tests

@implementation HelloMixpanelTests

- (void)setUp
{
    NSLog(@"starting test setup...");
    [super setUp];
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN launchOptions:nil andFlushInterval:0];
    [self.mixpanel reset];
    self.mixpanelWillFlush = NO;
    [self waitForSerialQueue];

    NSLog(@"finished test setup");
}

- (void)tearDown
{
    [super tearDown];
    self.mixpanel = nil;
}

- (void)setupHTTPServer
{
    if (!self.httpServer) {
        self.httpServer = [[HTTPServer alloc] init];
        [self.httpServer setConnectionClass:[MixpanelDummyHTTPConnection class]];
        [self.httpServer setType:@"_http._tcp."];
        [self.httpServer setPort:31337];

        NSString *webPath = [[NSBundle mainBundle] resourcePath];
        [self.httpServer setDocumentRoot:webPath];

        NSError *error;
        if ([self.httpServer start:&error]) {
            NSLog(@"Started HTTP Server on port %hu", [self.httpServer listeningPort]);
        } else {
            NSLog(@"Error starting HTTP Server: %@", error);
        }
    }
}

- (void)waitForSerialQueue
{
    NSLog(@"starting wait for serial queue...");
    dispatch_sync(self.mixpanel.serialQueue, ^{ return; });
    NSLog(@"finished wait for serial queue");
}

- (void)waitForAsyncQueue
{
    __block BOOL hasCalledBack = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ hasCalledBack = true; });
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
    while (hasCalledBack == NO && [loopUntil timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
    }
}

- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel
{
    return self.mixpanelWillFlush;
}

- (NSDictionary *)allPropertyTypes
{
    NSNumber *number = @3;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    NSDate *date = [dateFormatter dateFromString:@"2012-09-28 19:14:36 PDT"];
    NSDictionary *dictionary = @{@"k": @"v"};
    NSArray *array = @[@"1"];
    NSNull *null = [NSNull null];
    NSDictionary *nested = @{@"p1": @{@"p2": @[@{@"p3": @[@"bottom"]}]}};
    NSURL *url = [NSURL URLWithString:@"https://mixpanel.com/"];
    return @{@"string": @"yello",
            @"number": number,
            @"date": date,
            @"dictionary": dictionary,
            @"array": array,
            @"null": null,
            @"nested": nested,
            @"url": url,
            @"float": @1.3};
}

- (void)assertDefaultPeopleProperties:(NSDictionary *)p
{
    XCTAssertNotNil(p[@"$ios_device_model"], @"missing $ios_device_model property");
    XCTAssertNotNil(p[@"$ios_lib_version"], @"missing $ios_lib_version property");
    XCTAssertNotNil(p[@"$ios_version"], @"missing $ios_version property");
    XCTAssertNotNil(p[@"$ios_app_version"], @"missing $ios_app_version property");
    XCTAssertNotNil(p[@"$ios_app_release"], @"missing $ios_app_release property");
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

- (void)testHTTPServer
{
    [self setupHTTPServer];
    int requestCount = [MixpanelDummyHTTPConnection getRequestCount];

    NSString *post = @"Test Data";
    NSURL *url = [NSURL URLWithString:[@"http://localhost:31337" stringByAppendingString:@"/engage/"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[post dataUsingEncoding:NSUTF8StringEncoding]];
    NSError *error = nil;
    NSURLResponse *urlResponse = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
    NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    XCTAssertTrue([response length] > 0, @"HTTP server response not valid");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 1, @"One server request should have been made");
}

- (void)testFlushEvents
{
    [self setupHTTPServer];
    self.mixpanel.serverURL = @"http://localhost:31337";
    self.mixpanel.delegate = self;
    self.mixpanelWillFlush = YES;
    int requestCount = [MixpanelDummyHTTPConnection getRequestCount];

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events should have been flushed");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 1, @"50 events should have been batched in 1 HTTP request");

    requestCount = [MixpanelDummyHTTPConnection getRequestCount];
    for (NSUInteger i=0, n=60; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events should have been flushed");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 2, @"60 events should have been batched in 2 HTTP requests");
}

- (void)testFlushPeople
{
    [self setupHTTPServer];
    self.mixpanel.serverURL = @"http://localhost:31337";
    self.mixpanel.delegate = self;
    self.mixpanelWillFlush = YES;
    int requestCount = [MixpanelDummyHTTPConnection getRequestCount];

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"people should have been flushed");
    XCTAssertEqual(requestCount + 1, [MixpanelDummyHTTPConnection getRequestCount], @"50 people properties should have been batched in 1 HTTP request");

    requestCount = [MixpanelDummyHTTPConnection getRequestCount];
    for (NSUInteger i=0, n=60; i<n; i++) {
        [self.mixpanel.people set:@"p1" to:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
    }
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"people should have been flushed");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 2, @"60 people properties should have been batched in 2 HTTP requests");
}

- (void)testFlushFailure
{
    [self setupHTTPServer];
    self.mixpanel.serverURL = @"http://a.b.c.d"; //invalid
    self.mixpanel.delegate = self;
    self.mixpanelWillFlush = YES;
    int requestCount = [MixpanelDummyHTTPConnection getRequestCount];

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=50; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50U, @"50 events should be queued up");
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue([self.mixpanel.eventsQueue count] == 50U, @"events should still be in the queue if flush fails");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 0, @"The request should have failed.");
}

- (void)testAddingEventsAfterFlush
{
    [self setupHTTPServer];
    self.mixpanel.serverURL = @"http://localhost:31337";
    self.mixpanel.delegate = self;
    self.mixpanelWillFlush = YES;
    int requestCount = [MixpanelDummyHTTPConnection getRequestCount];

    [self.mixpanel identify:@"d1"];
    for (NSUInteger i=0, n=10; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 10U, @"10 events should be queued up");
    [self.mixpanel flush];
    for (NSUInteger i=0, n=5; i<n; i++) {
        [self.mixpanel track:[NSString stringWithFormat:@"event %lu", (unsigned long)i]];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 5U, @"5 more events should be queued up");
    [self.mixpanel flush];
    [self waitForSerialQueue];

    XCTAssertTrue([self.mixpanel.eventsQueue count] == 0, @"events should have been flushed");
    XCTAssertEqual([MixpanelDummyHTTPConnection getRequestCount] - requestCount, 2, @"There should be 2 HTTP requests");
}

- (void)testIdentify
{
    NSLog(@"starting testIdentify...");
    for (NSInteger i = 0; i < 2; i++) { // run this twice to test reset works correctly wrt to distinct ids
        NSString *distinctId = @"d1";
        // try this for IFA, ODIN and nil
        XCTAssertEqualObjects(self.mixpanel.distinctId, self.mixpanel.defaultDistinctId, @"mixpanel identify failed to set default distinct id");
        XCTAssertNil(self.mixpanel.people.distinctId, @"mixpanel people distinct id should default to nil");
        [self.mixpanel track:@"e1"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"events should be sent right away with default distinct id");
        XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"], self.mixpanel.defaultDistinctId, @"events should use default distinct id if none set");
        [self.mixpanel.people set:@"p1" to:@"a"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people records should go to unidentified queue before identify:");
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 1, @"unidentified people records not queued");
        XCTAssertEqualObjects(self.mixpanel.people.unidentifiedQueue.lastObject[@"$token"], TEST_TOKEN, @"incorrect project token in people record");
        [self.mixpanel identify:distinctId];
        [self waitForSerialQueue];
        XCTAssertEqualObjects(self.mixpanel.distinctId, distinctId, @"mixpanel identify failed to set distinct id");
        XCTAssertEqualObjects(self.mixpanel.people.distinctId, distinctId, @"mixpanel identify failed to set people distinct id");
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"identify: should move records from unidentified queue");
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"identify: should move records to main people queue");
        XCTAssertEqualObjects(self.mixpanel.peopleQueue.lastObject[@"$token"], TEST_TOKEN, @"incorrect project token in people record");
        XCTAssertEqualObjects(self.mixpanel.peopleQueue.lastObject[@"$distinct_id"], distinctId, @"distinct id not set properly on unidentified people record");
        NSDictionary *p = self.mixpanel.peopleQueue.lastObject[@"$set"];
        XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
        [self assertDefaultPeopleProperties:p];
        [self.mixpanel.people set:@"p1" to:@"a"];
        [self waitForSerialQueue];
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"once idenitfy: is called, unidentified queue should be skipped");
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 2, @"once identify: is called, records should go straight to main queue");
        [self.mixpanel track:@"e2"];
        [self waitForSerialQueue];
        XCTAssertEqual(self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"], distinctId, @"events should use new distinct id after identify:");
        [self.mixpanel reset];
        [self waitForSerialQueue];
    }
    NSLog(@"finished testIdentify");
}

- (void)testTrack
{
    NSLog(@"starting testTrack...");
    [self.mixpanel track:@"Something Happened"];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqual(e[@"event"], @"Something Happened", @"incorrect event name");
    NSDictionary *p = e[@"properties"];
    XCTAssertNotNil(p[@"$app_version"], @"$app_version not set");
    XCTAssertNotNil(p[@"$app_release"], @"$app_release not set");
    XCTAssertNotNil(p[@"$lib_version"], @"$lib_version not set");
    XCTAssertEqualObjects(p[@"$manufacturer"], @"Apple", @"incorrect $manufacturer");
    XCTAssertNotNil(p[@"$model"], @"$model not set");
    XCTAssertNotNil(p[@"$os"], @"$os not set");
    XCTAssertNotNil(p[@"$os_version"], @"$os_version not set");
    XCTAssertNotNil(p[@"$screen_height"], @"$screen_height not set");
    XCTAssertNotNil(p[@"$screen_width"], @"$screen_width not set");
    XCTAssertNotNil(p[@"distinct_id"], @"distinct_id not set");
    XCTAssertNotNil(p[@"mp_device_model"], @"mp_device_model not set");
    XCTAssertEqualObjects(p[@"mp_lib"], @"iphone", @"incorrect mp_lib");
    XCTAssertNotNil(p[@"time"], @"time not set");
    XCTAssertEqualObjects(p[@"token"], TEST_TOKEN, @"incorrect token");
    NSLog(@"finished testTrack");
}

- (void)testTrackProperties
{
    NSDictionary *p = @{@"string": @"yello",
                       @"number": @3,
                       @"date": [NSDate date],
                       @"$app_version": @"override"};
    [self.mixpanel track:@"Something Happened" properties:p];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqual(e[@"event"], @"Something Happened", @"incorrect event name");
    p = e[@"properties"];
    XCTAssertEqualObjects(p[@"$app_version"], @"override", @"reserved property override failed");
}

- (void)testDateEncoding
{
    NSDate *fixedDate = [NSDate dateWithTimeIntervalSince1970:1400000000];
    NSArray *a = @[@{@"event": @"an event",
                     @"properties": @{@"eventdate": fixedDate}}];
    NSString *json = [[NSString alloc] initWithData:[self.mixpanel JSONSerializeObject:a] encoding:NSUTF8StringEncoding];
    XCTAssert([json rangeOfString:@"\"eventdate\":\"2014-05-13T16:53:20.000Z\""].location != NSNotFound);
}

- (void)testTrackWithCustomDistinctIdAndToken
{
    NSDictionary *p = @{@"token": @"t1",
                       @"distinct_id": @"d1"};
    [self.mixpanel track:@"e1" properties:p];
    [self waitForSerialQueue];
    NSString *trackToken = self.mixpanel.eventsQueue.lastObject[@"properties"][@"token"];
    NSString *trackDistinctId = self.mixpanel.eventsQueue.lastObject[@"properties"][@"distinct_id"];
    XCTAssertEqualObjects(trackToken, @"t1", @"user-defined distinct id not used in track. got: %@", trackToken);
    XCTAssertEqualObjects(trackDistinctId, @"d1", @"user-defined distinct id not used in track. got: %@", trackDistinctId);
}

- (void)testSuperProperties
{
    NSDictionary *p = @{@"p1": @"a",
                       @"p2": @3,
                       @"p2": [NSDate date]};
    [self.mixpanel registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties], p, @"register super properties failed");
    p = @{@"p1": @"b"};
    [self.mixpanel registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p1"], @"b",
                         @"register super properties failed to overwrite existing value");
    p = @{@"p4": @"a"};
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed first time");
    p = @{@"p4": @"b"};
    [self.mixpanel registerSuperPropertiesOnce:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once failed second time");
    p = @{@"p4": @"c"};
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"d"];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"a",
                         @"register super properties once with default value failed when no match");
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"a"];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.mixpanel currentSuperProperties][@"p4"], @"c",
                         @"register super properties once with default value failed when match");
    [self.mixpanel unregisterSuperProperty:@"a"];
    [self waitForSerialQueue];
    XCTAssertNil([self.mixpanel currentSuperProperties][@"a"],
                         @"unregister super property failed");
    XCTAssertNoThrow([self.mixpanel unregisterSuperProperty:@"a"], @"unregister non-existent super property should not throw");
    [self.mixpanel clearSuperProperties];
    [self waitForSerialQueue];
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"clear super properties failed");
}

- (void)testAssertPropertyTypes
{
    NSDictionary *p = @{@"data": [NSData data]};
    XCTAssertThrows([self.mixpanel track:@"e1" properties:p], @"property type should not be allowed");
    XCTAssertThrows([self.mixpanel registerSuperProperties:p], @"property type should not be allowed");
    XCTAssertThrows([self.mixpanel registerSuperPropertiesOnce:p], @"property type should not be allowed");
    XCTAssertThrows([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"], @"property type should not be allowed");
    p = [self allPropertyTypes];
    XCTAssertNoThrow([self.mixpanel track:@"e1" properties:p], @"property type should be allowed");
    XCTAssertNoThrow([self.mixpanel registerSuperProperties:p], @"property type should be allowed");
    XCTAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p],  @"property type should be allowed");
    XCTAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"],  @"property type should be allowed");
}

- (void)testTrackLaunchOptions
{
    Mixpanel *mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN
                                           launchOptions:@{UIApplicationLaunchOptionsRemoteNotificationKey: @{@"mp": @{
                                                                                                              @"m": @"the_message_id",
                                                                                                              @"c": @"the_campaign_id"
                                                                                                              }}} andFlushInterval:0];
    NSLog(@"starting wait for serial queue...");
    dispatch_sync(mixpanel.serialQueue, ^{ return; });
    NSLog(@"finished wait for serial queue");
    XCTAssertTrue(mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(e[@"event"], @"$app_open", @"incorrect event name");
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"campaign_id"], @"the_campaign_id", @"campaign_id not equal");
    XCTAssertEqualObjects(p[@"message_id"], @"the_message_id", @"message_id not equal");
    XCTAssertEqualObjects(p[@"message_type"], @"push", @"type does not equal inapp");
    NSLog(@"finished testTrackLaunchOptions");
}

- (void)testTrackPushNotification
{
    [self.mixpanel trackPushNotification:@{@"mp": @{
       @"m": @"the_message_id",
       @"c": @"the_campaign_id"
    }}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    XCTAssertEqualObjects(e[@"event"], @"$campaign_received", @"incorrect event name");
    NSDictionary *p = e[@"properties"];
    XCTAssertEqualObjects(p[@"campaign_id"], @"the_campaign_id", @"campaign_id not equal");
    XCTAssertEqualObjects(p[@"message_id"], @"the_message_id", @"message_id not equal");
    XCTAssertEqualObjects(p[@"message_type"], @"push", @"type does not equal inapp");
    NSLog(@"finished testTrackPushNotification");
}

- (void)testTrackPushNotificationMalformed
{
    [self.mixpanel trackPushNotification:@{@"mp": @{
                                                   @"m": @"the_message_id",
                                                   @"cid": @"the_campaign_id"
                                                   }}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    [self.mixpanel trackPushNotification:@{@"mp": @1}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    [self.mixpanel trackPushNotification:nil];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    [self.mixpanel trackPushNotification:@{}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    [self.mixpanel trackPushNotification:@{@"mp": @"bad value"}];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    NSDictionary *badUserInfo = @{@"mp": @{
                                         @"m": [NSData data],
                                         @"c": [NSData data]
                                         }};
    XCTAssertThrows([self.mixpanel trackPushNotification:badUserInfo], @"property types should not be allowed");
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"event was queued");
    NSLog(@"finished testTrackPushNotificationMalformed");
}

- (void)testReset
{
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel identify:@"d1"];
    self.mixpanel.nameTag = @"n1";
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people set:p];
    [self.mixpanel archive];
    [self.mixpanel reset];
    [self waitForSerialQueue];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset");
    XCTAssertNil(self.mixpanel.nameTag, @"name tag failed to reset");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"super properties failed to reset");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset");
    XCTAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset");
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset after archive");
    XCTAssertNil(self.mixpanel.nameTag, @"name tag failed to reset after archive");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"super properties failed to reset after archive");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset after archive");
    XCTAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset after archive");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset after archive");
}

- (void)testArchive
{
    [self.mixpanel archive];
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id archive failed");
    XCTAssertNil(self.mixpanel.nameTag, @"default name tag archive failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties archive failed");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue archive failed");
    XCTAssertNil(self.mixpanel.people.distinctId, @"default people distinct id archive failed");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue archive failed");
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel identify:@"d1"];
    self.mixpanel.nameTag = @"n1";
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people set:p];
    self.mixpanel.timedEvents[@"e2"] = @5.0;
    [self waitForSerialQueue];
    [self.mixpanel archive];
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.mixpanel.distinctId, @"d1", @"custom distinct archive failed");
    XCTAssertEqualObjects(self.mixpanel.nameTag, @"n1", @"custom name tag archive failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 1, @"custom super properties archive failed");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"e1", @"event was not successfully archived/unarchived");
    XCTAssertEqualObjects(self.mixpanel.people.distinctId, @"d1", @"custom people distinct id archive failed");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"pending people queue archive failed");
    XCTAssertEqualObjects(self.mixpanel.timedEvents[@"e2"], @5.0, @"timedEvents archive failed");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    XCTAssertFalse([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"events archive file not removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"people archive file not removed");
    XCTAssertFalse([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"properties archive file not removed");
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id from no file failed");
    XCTAssertNil(self.mixpanel.nameTag, @"default name tag archive from no file failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties from no file failed");
    XCTAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from no file is nil");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue from no file not empty");
    XCTAssertNil(self.mixpanel.people.distinctId, @"default people distinct id from no file failed");
    XCTAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from no file is nil");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue from no file not empty");
    XCTAssertTrue(self.mixpanel.timedEvents.count == 0, @"timedEvents is not empty");
    // corrupt file
    NSData *garbage = [@"garbage" dataUsingEncoding:NSUTF8StringEncoding];
    [garbage writeToFile:[self.mixpanel eventsFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel peopleFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel propertiesFilePath] atomically:NO];
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"garbage events archive file not found");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"garbage people archive file not found");
    XCTAssertTrue([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"garbage properties archive file not found");
    self.mixpanel = [[Mixpanel alloc] initWithToken:TEST_TOKEN launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id from garbage failed");
    XCTAssertNil(self.mixpanel.nameTag, @"default name tag archive from garbage failed");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties from garbage failed");
    XCTAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from garbage is nil");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue from garbage not empty");
    XCTAssertNil(self.mixpanel.people.distinctId, @"default people distinct id from garbage failed");
    XCTAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from garbage is nil");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue from garbage not empty");
    XCTAssertTrue(self.mixpanel.timedEvents.count == 0, @"timedEvents is not empty");
}

- (void)testPeopleAddPushDeviceToken
{
    [self.mixpanel identify:@"d1"];
    NSData *token = [@"0123456789abcdef" dataUsingEncoding:[NSString defaultCStringEncoding]];
    [self.mixpanel.people addPushDeviceToken:token];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$union"], @"$union dictionary missing");
    NSDictionary *p = r[@"$union"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    NSArray *a = p[@"$ios_devices"];
    XCTAssertTrue(a.count == 1, @"device token array not set");
    XCTAssertEqualObjects(a.lastObject, @"30313233343536373839616263646566", @"device token not encoded properly");
}

- (void)testPeopleSet
{
    [self.mixpanel identify:@"d1"];
    [self waitForSerialQueue];
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel.people set:p];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$time"], @"$time timestamp missing");
    XCTAssertNotNil(r[@"$set"], @"$set dictionary missing");
    p = r[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleSetOnce
{
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{@"p1": @"a"};
    [self.mixpanel.people setOnce:p];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$time"], @"$time timestamp missing");
    XCTAssertNotNil(r[@"$set_once"], @"$set dictionary missing");
    p = r[@"$set_once"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleSetReservedProperty
{
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{@"$ios_app_version": @"override"};
    [self.mixpanel.people set:p];
    [self waitForSerialQueue];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    p = r[@"$set"];
    XCTAssertEqualObjects(p[@"$ios_app_version"], @"override", @"reserved property override failed");
}

- (void)testPeopleSetTo
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$set"], @"$set dictionary missing");
    NSDictionary *p = r[@"$set"];
    XCTAssertEqualObjects(p[@"p1"], @"a", @"custom people property not queued");
    [self assertDefaultPeopleProperties:p];
}

- (void)testPeopleIncrement
{
    [self.mixpanel identify:@"d1"];
    NSDictionary *p = @{@"p1": @3};
    [self.mixpanel.people increment:p];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$add"], @"$add dictionary missing");
    p = r[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
}

- (void)testPeopleIncrementBy
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people increment:@"p1" by:@3];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$add"], @"$add dictionary missing");
    NSDictionary *p = r[@"$add"];
    XCTAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    XCTAssertEqualObjects(p[@"p1"], @3, @"custom people property not queued");
}

- (void)testPeopleDeleteUser
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people deleteUser];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$token"], TEST_TOKEN, @"project token not set");
    XCTAssertEqualObjects(r[@"$distinct_id"], @"d1", @"distinct id not set");
    XCTAssertNotNil(r[@"$delete"], @"$delete dictionary missing");
    NSDictionary *p = r[@"$delete"];
    XCTAssertTrue(p.count == 0, @"incorrect people properties: %@", p);
}

- (void)testMixpanelDelegate
{
    self.mixpanel.delegate = self;
    [self.mixpanel identify:@"d1"];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    [self.mixpanel flush];
    [self waitForSerialQueue];
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"delegate should have stopped flush");
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, @"delegate should have stopped flush");
}

- (void)testPeopleAssertPropertyTypes
{
    NSDictionary *p = @{@"URL": [NSData data]};
    XCTAssertThrows([self.mixpanel.people set:p], @"unsupported property allowed");
    XCTAssertThrows([self.mixpanel.people set:@"p1" to:[NSData data]], @"unsupported property allowed");
    p = @{@"p1": @"a"}; // increment should require a number
    XCTAssertThrows([self.mixpanel.people increment:p], @"unsupported property allowed");
}

- (void)testNilArguments
{
    [self.mixpanel identify:nil];
    XCTAssertNil(self.mixpanel.people.distinctId, @"identify nil should make distinct id nil");
    [self.mixpanel track:nil];
    [self.mixpanel track:nil properties:nil];
    [self.mixpanel registerSuperProperties:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil defaultValue:nil];
    [self waitForSerialQueue];
    // legacy behavior
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 2, @"track with nil should create mp_event event");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"mp_event", @"track with nil should create mp_event event");
    XCTAssertNotNil([self.mixpanel currentSuperProperties], @"setting super properties to nil should have no effect");
    XCTAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"setting super properties to nil should have no effect");
    [self.mixpanel identify:nil];
    XCTAssertNil(self.mixpanel.people.distinctId, @"identify nil should make people distinct id nil");
    XCTAssertThrows([self.mixpanel.people set:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:nil to:@"a"], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:@"p1" to:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people set:nil to:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil by:@3], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:@"p1" by:nil], @"should not take nil argument");
    XCTAssertThrows([self.mixpanel.people increment:nil by:nil], @"should not take nil argument");
}

- (void)testPeopleTrackCharge
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people trackCharge:@25];
    [self waitForSerialQueue];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self.mixpanel.peopleQueue removeAllObjects];
    [self.mixpanel.people trackCharge:@25.34];
    [self waitForSerialQueue];
    r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25.34);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self.mixpanel.peopleQueue removeAllObjects];
    // require a number
    XCTAssertThrows([self.mixpanel.people trackCharge:nil]);
    XCTAssertTrue(self.mixpanel.peopleQueue.count == 0);
    // but allow 0
    [self.mixpanel.people trackCharge:@0];
    [self waitForSerialQueue];
    r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @0);
    XCTAssertNotNil(r[@"$append"][@"$transactions"][@"$time"]);
    [self.mixpanel.peopleQueue removeAllObjects];
    // allow $time override
    NSDictionary *p = [self allPropertyTypes];
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"$time": p[@"date"]}];
    [self waitForSerialQueue];
    r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$time"], p[@"date"]);
    [self.mixpanel.peopleQueue removeAllObjects];
    // allow arbitrary charge properties
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"p1": @"a"}];
    [self waitForSerialQueue];
    r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25);
    XCTAssertEqualObjects(r[@"$append"][@"$transactions"][@"p1"], @"a");
}

- (void)testPeopleClearCharges
{
    [self.mixpanel identify:@"d1"];
    [self.mixpanel.people clearCharges];
    [self waitForSerialQueue];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    XCTAssertEqualObjects(r[@"$set"][@"$transactions"], @[]);
}

- (void)testDropEvents
{
    for (NSInteger i = 0; i < 505; i++) {
        [self.mixpanel track:@"rapid_event" properties:@{@"i": @(i)}];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.eventsQueue count] == 500);
    NSDictionary *e = self.mixpanel.eventsQueue[0];
    XCTAssertEqualObjects(e[@"properties"][@"i"], @(5));
    e = [self.mixpanel.eventsQueue lastObject];
    XCTAssertEqualObjects(e[@"properties"][@"i"], @(504));
}

- (void)testDropUnidentifiedPeopleRecords
{
    for (NSInteger i = 0; i < 505; i++) {
        [self.mixpanel.people set:@"i" to:@(i)];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.people.unidentifiedQueue count] == 500);
    NSDictionary *r = self.mixpanel.people.unidentifiedQueue[0];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(5));
    r = [self.mixpanel.people.unidentifiedQueue lastObject];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
}

- (void)testDropPeopleRecords
{
    [self.mixpanel identify:@"d1"];
    for (NSInteger i = 0; i < 505; i++) {
        [self.mixpanel.people set:@"i" to:@(i)];
    }
    [self waitForSerialQueue];
    XCTAssertTrue([self.mixpanel.peopleQueue count] == 500);
    NSDictionary *r = self.mixpanel.peopleQueue[0];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(5));
    r = [self.mixpanel.peopleQueue lastObject];
    XCTAssertEqualObjects(r[@"$set"][@"i"], @(504));
}

- (void)testParseSurvey
{
    // invalid (no name)
    NSDictionary *invalid = @{@"id": @3,
                        @"collections": @[@{@"id": @9}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};
    XCTAssertNil([MPSurvey surveyWithJSONObject:invalid]);

    // valid
    NSDictionary *o = @{@"id": @3,
                        @"name": @"survey",
                        @"collections": @[@{@"id": @9, @"name": @"collection"}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};
    XCTAssertNotNil([MPSurvey surveyWithJSONObject:o]);

    // nil
    XCTAssertNil([MPSurvey surveyWithJSONObject:nil]);

    // empty
    XCTAssertNil([MPSurvey surveyWithJSONObject:@{}]);

    // garbage keys
    XCTAssertNil([MPSurvey surveyWithJSONObject:@{@"blah": @"foo"}]);

    NSMutableDictionary *m;

    // invalid id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"id"] = @NO;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // invalid collections
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"collections"] = @NO;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // empty collections
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"collections"] = @[];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // invalid collections item
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"collections"] = @[@NO];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // collections item with no id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"collections"] = @[@{@"bo": @"knows"}];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // no questions
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"questions"] = @[];
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // 1 invalid question
    NSArray *q = @[@{
                       @"id": @NO,
                       @"type": @"text",
                       @"prompt": @"Anything else?",
                       @"extra_data": @{}}];
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"questions"] = q;
    XCTAssertNil([MPSurvey surveyWithJSONObject:m]);

    // 1 invalid question, 1 good question
    q = @[@{
              @"id": @NO,
              @"type": @"text",
              @"prompt": @"Anything else?",
              @"extra_data": @{}},
          @{
              @"id": @3,
              @"type": @"text",
              @"prompt": @"Anything else?",
              @"extra_data": @{}}];
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"questions"] = q;
    MPSurvey *s = [MPSurvey surveyWithJSONObject:m];
    XCTAssertNotNil(s);
    XCTAssertEqual([s.questions count], (NSUInteger)1);
}

- (void)testParseSurveyQuestion
{
    // valid
    NSDictionary *o = @{
                        @"id": @12,
                        @"type": @"text",
                        @"prompt": @"Anything else?",
                        @"extra_data": @{}};
    XCTAssertNotNil([MPSurveyQuestion questionWithJSONObject:o]);

    // nil
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:nil]);

    // empty
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:@{}]);

    // garbage keys
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:@{@"blah": @"foo"}]);

    NSMutableDictionary *m;

    // invalid id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"id"] = @NO;
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);

    // invalid question type
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"type"] = @"not_supported";
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);

    // empty prompt
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"prompt"] = @"";
    XCTAssertNil([MPSurveyQuestion questionWithJSONObject:m]);
}

- (void)testParseNotification
{
    // invalid bad title
    NSDictionary *invalid = @{@"id": @3,
                              @"title": @5,
                              @"type": @"takeover",
                              @"body": @"Hi!",
                              @"cta_url": @"blah blah blah",
                              @"cta": [NSNull null],
                              @"image_url": @[]};

    XCTAssertNil([MPNotification notificationWithJSONObject:invalid]);

    // valid
    NSDictionary *o = @{@"id": @3,
                        @"message_id": @1,
                        @"title": @"title",
                        @"type": @"takeover",
                        @"body": @"body",
                        @"cta": @"cta",
                        @"cta_url": @"maps://",
                        @"image_url": @"http://mixpanel.com/coolimage.png"};

    XCTAssertNotNil([MPNotification notificationWithJSONObject:o]);

    // nil
    XCTAssertNil([MPNotification notificationWithJSONObject:nil]);

    // empty
    XCTAssertNil([MPNotification notificationWithJSONObject:@{}]);

    // garbage keys
    XCTAssertNil([MPNotification notificationWithJSONObject:@{@"gar": @"bage"}]);

    NSMutableDictionary *m;

    // invalid id
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"id"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid title
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"title"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid body
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"body"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid cta
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"cta"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid cta_url
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"cta_url"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid image_urls
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @NO;
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // invalid image_urls item
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @[@NO];
    XCTAssertNil([MPNotification notificationWithJSONObject:m]);

    // an image with a space in the URL should be % encoded
    m = [NSMutableDictionary dictionaryWithDictionary:o];
    m[@"image_url"] = @"http://test.com/animagewithaspace init.jpg";
    XCTAssertNotNil([MPNotification notificationWithJSONObject:m]);

}

- (void)testNoDoubleShowNotification
{
    NSDictionary *o = @{@"id": @3,
                        @"message_id": @1,
                        @"title": @"title",
                        @"type": @"takeover",
                        @"body": @"body",
                        @"cta": @"cta",
                        @"cta_url": @"maps://",
                        @"image_url": @"http://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png"};
    MPNotification *notif = [MPNotification notificationWithJSONObject:o];
    [self.mixpanel showNotificationWithObject:notif];
    [self.mixpanel showNotificationWithObject:notif];

    //wait for notifs to be shown from main queue
    [self waitForAsyncQueue];

    UIViewController *topVC = [self topViewController];
    XCTAssertTrue([topVC isKindOfClass:[MPNotificationViewController class]], @"Notification was not presented");
    XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, @"should only show same notification once (and track 1 notif shown event)");
    XCTAssertEqualObjects(self.mixpanel.eventsQueue.lastObject[@"event"], @"$campaign_delivery", @"last event should be campaign delivery");

    // Clean up
    if ([self respondsToSelector:@selector(expectationWithDescription:)]) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"notification closed"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self.mixpanel.currentlyShowingNotification = nil;
            self.mixpanel.notificationViewController = nil;
            if([topVC isKindOfClass:[MPNotificationViewController class]]) {
                [(MPNotificationViewController *)topVC hideWithAnimation:YES completion:^void{
                    [expectation fulfill];
                }];
            }
        });
        [self waitForExpectationsWithTimeout:self.mixpanel.miniNotificationPresentationTime * 2 handler:nil];
    }
}

- (void)testNoShowSurveyOnPresentingVC
{
    NSDictionary *o = @{@"id": @3,
                        @"name": @"survey",
                        @"collections": @[@{@"id": @9, @"name": @"collection"}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};

    MPSurvey *survey = [MPSurvey surveyWithJSONObject:o];

    //Start presenting a View Controller on the current root
    UIViewController *topViewController = [self topViewController];

    __block BOOL waitForBlock = YES;
    [topViewController presentViewController:[[UIViewController alloc]init] animated:YES completion:^{ waitForBlock = NO; }];

    //Survey should not show as it cannot present on top of a currently presenting view controller
    [self.mixpanel presentSurveyWithRootViewController:survey];

    XCTAssertFalse([[self topViewController] isKindOfClass:[MPSurveyNavigationController class]], @"Survey was presented when it shouldn't have been");

    //Wait for original VC to present, so we don't interfere with subsequent tests.
    while(waitForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (void)testShowSurvey
{
    NSDictionary *o = @{@"id": @3,
                        @"name": @"survey",
                        @"collections": @[@{@"id": @9, @"name": @"collection"}],
                        @"questions": @[@{
                                            @"id": @12,
                                            @"type": @"text",
                                            @"prompt": @"Anything else?",
                                            @"extra_data": @{}}]};

    MPSurvey *survey = [MPSurvey surveyWithJSONObject:o];

    [self.mixpanel presentSurveyWithRootViewController:survey];
    UIViewController *topVC = [self topViewController];
    XCTAssertTrue([topVC isKindOfClass:[MPSurveyNavigationController class]], @"Survey was not presented");

    // Clean up
    if ([self respondsToSelector:@selector(expectationWithDescription:)]) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"survey closed"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self.mixpanel.currentlyShowingSurvey = nil;
            [(MPSurveyNavigationController *)topVC.presentingViewController dismissViewControllerAnimated:NO completion:^{
                [expectation fulfill];
            }];
        });
        [self waitForExpectationsWithTimeout:10 handler:nil];
    }
}

- (void)testEventTiming
{
    [self.mixpanel track:@"Something Happened"];
    [self waitForSerialQueue];
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    NSDictionary *p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"New events should not be timed.");

    [self.mixpanel timeEvent:@"400 Meters"];

    [self.mixpanel track:@"500 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"The exact same event name is required for timing.");

    [self.mixpanel track:@"400 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNotNil(p[@"$duration"], @"This event should be timed.");

    [self.mixpanel track:@"400 Meters"];
    [self waitForSerialQueue];
    e = self.mixpanel.eventsQueue.lastObject;
    p = e[@"properties"];
    XCTAssertNil(p[@"$duration"], @"Tracking the same event should require a second call to timeEvent.");
}

- (void)testTelephonyInfoInitialized
{
    XCTAssertNotNil([self.mixpanel performSelector:@selector(telephonyInfo)], @"telephonyInfo wasn't initialized");
}

@end
