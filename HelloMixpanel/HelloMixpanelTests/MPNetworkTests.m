//
//  MPNetworkTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPNetworkTests.h"
#import "MPNetwork.h"

@implementation MPNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
    
    NSURL *serverURL = [NSURL URLWithString:@"http://localhost:31337"];
    self.network = [[MPNetwork alloc] initWithServerURL:serverURL];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    self.network = nil;
}

#pragma mark - Request Creation
- (void)testRequestForTrackEndpoint {
    NSString *body = @"track test body";
    NSURLRequest *request = [self.network requestForEndpoint:@"/track/"
                                                    withBody:body];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://localhost:31337/track/"]);
    XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
    XCTAssertEqualObjects(request.HTTPBody, [body dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssert([request.allHTTPHeaderFields[@"Accept-Encoding"] isEqualToString:@"gzip"]);
}

- (void)testRequestForPeopleEndpoint {
    NSString *body = @"engage test body";
    NSURLRequest *request = [self.network requestForEndpoint:@"/engage/"
                                                    withBody:body];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://localhost:31337/engage/"]);
    XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
    XCTAssertEqualObjects(request.HTTPBody, [body dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssert([request.allHTTPHeaderFields[@"Accept-Encoding"] isEqualToString:@"gzip"]);
}

#pragma mark - Enabled
//
// Disabling MPNetwork should render the flush timer in valid
//
- (void)testDisabledAndFlush {
    self.network.enabled = NO;
    XCTAssert(!self.network.flushTimer.isValid, @"Disabling MPNetwork should render the timer invalid.");
}

//
// Disabling MPNetwork should render the flush timer in valid
//
- (void)testEnabledAndFlush {
    self.network.enabled = YES;
    XCTAssert(self.network.flushTimer.isValid, @"Disabling MPNetwork should render the timer invalid.");
}

//
// Updating the networking activity indicator should work if we are managing it
//
- (void)testNetworkActivityManagementEnabled {
    self.network.shouldManageNetworkActivityIndicator = YES;
    
    BOOL oldState = [UIApplication sharedApplication].isNetworkActivityIndicatorVisible;
    [self.network updateNetworkActivityIndicator:!oldState];
    XCTAssert([UIApplication sharedApplication].networkActivityIndicatorVisible != oldState,
              @"Updating the network activity indicator had no effect, even though we are managing it.");
}

//
// Updating the networking activity indicator should not work if we are not managing it
//
- (void)testNetworkActivityManagementDisabled {
    self.network.shouldManageNetworkActivityIndicator = NO;
    
    BOOL currentState = [UIApplication sharedApplication].isNetworkActivityIndicatorVisible;
    [self.network updateNetworkActivityIndicator:!currentState];
    XCTAssert([UIApplication sharedApplication].isNetworkActivityIndicatorVisible == currentState,
              @"Updating the network activity indicator had an effect, even though we are not managing it.");
}

#pragma mark - Flush

#pragma mark Interval
//
// Custom flush intervals should be supported and setting them should restart the flush timer
//
- (void)testCustomFlushInterval {
    static const NSTimeInterval kCustomFlushInterval = 33.f;
    
    [self.network setFlushInterval:kCustomFlushInterval];
    XCTAssertEqualWithAccuracy(self.network.flushInterval, kCustomFlushInterval,
                               0.01f, @"Setting the flush interval did not update MPNetwork.");
    XCTAssertEqualWithAccuracy(self.network.flushTimer.timeInterval, kCustomFlushInterval,
                               0.01f, @"Setting the flush interval did not update the timeInterval "
                               "of the timer.");
    XCTAssert(self.network.flushTimer.isValid, @"Setting the flush interval did not start the flush timer.");
}

//
// Flush timer should have a default value of sixty seconds
//
- (void)testDefaultFlushInterval {
    static const NSTimeInterval kDefaultFlushInterval = 60.f;
    
    XCTAssertEqualWithAccuracy(self.network.flushInterval, kDefaultFlushInterval,
                               0.01f, @"Flush interval was initialized to the wrong default value");
}

#pragma mark Timer
//
// Starting and Stopping the flush timer
//
- (void)testFlushTimer {
    [self.network stopFlushTimer];
    XCTAssert(!self.network.flushTimer.isValid, @"Calling stopFlushTimer should render the timer invalid.");
    
    [self.network startFlushTimer];
    XCTAssert(self.network.flushTimer.isValid, @"Calling startFlushTimer should render the timer valid.");
}

#pragma mark Queue
//
// Flushing and empty event queue does nothing
//
- (void)testFlushEmptyEventQueue {
    [self.network flushEventQueue:[NSArray array]];
}

//
// Flushing an empty people queue does nothing
//
- (void)testFlushEmptyPeopleQueue {
    [self.network flushPeopleQueue:[NSArray array]];
}

// TODO: Add flushing tests.

#pragma mark - Encoding

//
// Encoding JSON strings to Base64 should match our expectations
//
- (void)testEncodeBase64 {
    NSString *eventsJSON = @"[{\"name\":\"test\"}]";
    NSData *eventsData = [eventsJSON dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64 = [MPNetwork encodeJSONDataAsBase64:eventsData];
    XCTAssert([base64 isEqualToString:@"W3sibmFtZSI6InRlc3QifV0="], @"Base64 encoding failed.");
}

//
// Encoding arrays to JSON strings should match our expectations
//
- (void)testEncodeJSON {
    NSArray *events = @[ @{ @"name": @"test" } ];
    NSData *data = [MPNetwork encodeArrayAsJSONData:events];
    NSString *eventsJSON = @"[{\"name\":\"test\"}]";
    XCTAssertEqualObjects(data, [eventsJSON dataUsingEncoding:NSUTF8StringEncoding], @"Encoded JSON data did "
                          "not match the specification");
}

//
// Encoding arrays for API should go to JSON, then Base64, and match our final expectations
//
- (void)testEncodeAPI {
    NSArray *events = @[ @{ @"name": @"test" } ];
    NSString *base64 = [MPNetwork encodeArrayForAPI:events];
    XCTAssert([base64 isEqualToString:@"W3sibmFtZSI6InRlc3QifV0="], @"API encoding failed.");
}

#pragma mark - HTTP Parsing
//
// HTTP "Retry-After" headers should parse to an NSTimeInterval correctly.
//
- (void)testRetryAfterHeaderParsing {
    static const NSTimeInterval kRetryAfter = 51.f;
    
    NSDictionary *headers = @{ @"Retry-After": @(kRetryAfter).stringValue };
    NSHTTPURLResponse *response = [MPNetworkTests responseWithStatus:200
                                                          andHeaders:headers];
    NSTimeInterval retryAfterTime = [MPNetwork parseRetryAfterTime:response];
    XCTAssertEqualWithAccuracy(retryAfterTime, kRetryAfter, 0.01f,
                               @"Parsed Retry-After time different from HTTP header field");
}

//
// HTTP Status codes of 200 should not be parsed as errors
//
- (void)testHTTPStatus200 {
    BOOL failure = [MPNetwork parseHTTPFailure:[MPNetworkTests responseWithStatus:200]
                                     withError:nil];
    XCTAssert(!failure, @"Parsed successful HTTP status 200 as a failure.");
}

//
// HTTP Status codes of 500 to 599 should be parsed as errors
//
- (void)testHTTPStatus5XX {
    BOOL failure = [MPNetwork parseHTTPFailure:[MPNetworkTests responseWithStatus:503]
                                     withError:nil];
    XCTAssert(failure, @"Failed to parse HTTP status 503 as an error.");
    
    failure = [MPNetwork parseHTTPFailure:[MPNetworkTests responseWithStatus:543]
                                withError:nil];
    XCTAssert(failure, @"Failed to parse HTTP status 543 as an error.");
    
    failure = [MPNetwork parseHTTPFailure:[MPNetworkTests responseWithStatus:599]
                                withError:nil];
    XCTAssert(failure, @"Failed to parse HTTP status 599 as an error.");
}

#pragma mark - HTTP Failure Handling
//
// Ensure successive failures result in an exponential back
//      off time.
//
- (void)testBackOffWithMultipleFailures {
    NSHTTPURLResponse *badStatusResponse = [MPNetworkTests responseWithStatus:503];
    
    // We need 2 consecutive failures to enable exponential back off
    [self.network handleNetworkResponse:badStatusResponse withError:nil];
    XCTAssert(self.network.consecutiveFailures == 1);
    [self.network handleNetworkResponse:badStatusResponse withError:nil];
    XCTAssert(self.network.consecutiveFailures == 2);
    
    NSTimeInterval backOffDuration = self.network.requestsDisabledUntilTime - [[NSDate date] timeIntervalSince1970];
    XCTAssertGreaterThan(backOffDuration, 120, @"Requests should back off between 120s and 150s with two "
                         "consecutive failures.");
    XCTAssertLessThanOrEqual(backOffDuration, 150, @"Requests should back off between 120s and 150s with two "
                             "consecutive failures.");
    
    // Create a third failure to check the back off time
    [self.network handleNetworkResponse:badStatusResponse withError:nil];
    XCTAssert(self.network.consecutiveFailures == 3);
    
    backOffDuration = self.network.requestsDisabledUntilTime - [[NSDate date] timeIntervalSince1970];
    XCTAssertGreaterThan(backOffDuration, 240, @"Requests should back off between 240s and 270s with three "
                         "consecutive failures.");
    XCTAssertLessThanOrEqual(backOffDuration, 270, @"Requests should back off between 240s and 270s with three "
                             "consecutive failures.");
}

//
// A single success after a number of failures should reset the back off time.
//
- (void)testFailureRecovery {
    // We need 2 consecutive failures to enable exponential back off
    [self.network handleNetworkResponse:[MPNetworkTests responseWithStatus:503]
                              withError:nil];
    XCTAssert(self.network.consecutiveFailures == 1);
    [self.network handleNetworkResponse:[MPNetworkTests responseWithStatus:503]
                              withError:nil];
    XCTAssert(self.network.consecutiveFailures == 2);
    
    [self.network handleNetworkResponse:[MPNetworkTests responseWithStatus:200]
                              withError:nil];
    XCTAssert(self.network.consecutiveFailures == 0, @"Consecutive failures followed by a success did not "
              "reset the failure count.");
    
    NSTimeInterval backOffDuration = self.network.requestsDisabledUntilTime - [[NSDate date] timeIntervalSince1970];
    XCTAssertLessThanOrEqual(backOffDuration, 0, @"Back off duration was not reset after a successful HTTP "
                             "response.");
}

#pragma mark - Test Utilities
+ (NSHTTPURLResponse *)responseWithStatus:(NSUInteger)statusCode {
    return [MPNetworkTests responseWithStatus:statusCode
                                   andHeaders:nil];
}

+ (NSHTTPURLResponse *)responseWithStatus:(NSUInteger)statusCode
                               andHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers {
    return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                       statusCode:statusCode
                                      HTTPVersion:@"HTTP/1.1"
                                     headerFields:headers];
}

@end
