//
//  MPNetworkTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPNetwork.h"
#import "MPNetworkPrivate.h"

@interface MPNetworkTests : XCTestCase

@property (nonatomic, strong) MPNetwork *network;

@end

@implementation MPNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
    
    NSURL *serverURL = [NSURL URLWithString:@"http://localhost:31337"];
    self.network = [[MPNetwork alloc] initWithServerURL:serverURL mixpanel:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    self.network = nil;
}

#pragma mark - Request Creation
- (void)testRequestForTrackEndpoint {
    NSString *body = @"track test body";
    NSURLRequest *request = [self.network buildPostRequestForEndpoint:MPNetworkEndpointTrack andBody:body];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://localhost:31337/track/"]);
    XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
    XCTAssertEqualObjects(request.HTTPBody, [body dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssert([request.allHTTPHeaderFields[@"Accept-Encoding"] isEqualToString:@"gzip"]);
}

- (void)testRequestForPeopleEndpoint {
    NSString *body = @"engage test body";
    NSURLRequest *request = [self.network buildPostRequestForEndpoint:MPNetworkEndpointEngage andBody:body];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://localhost:31337/engage/"]);
    XCTAssert([request.HTTPMethod isEqualToString:@"POST"]);
    XCTAssertEqualObjects(request.HTTPBody, [body dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssert([request.allHTTPHeaderFields[@"Accept-Encoding"] isEqualToString:@"gzip"]);
}

#pragma mark - Query Creation
- (void)testRequestForEndpointWithQueryItems {
    // Build the query items for decide
    NSArray *items = [MPNetwork buildDecideQueryForProperties:@{ @"test": @"4" }
                                               withDistinctID:@"1234"
                                                     andToken:@"deadc0de"];
    XCTAssertEqual(items.count, (unsigned long)5, @"returned the wrong number of query items.");
    
    NSURLRequest *request = [self.network buildGetRequestForEndpoint:MPNetworkEndpointDecide
                                                      withQueryItems:items];
    XCTAssertEqualObjects(request.URL.absoluteString, @"http://localhost:31337/decide?version=1&lib=iphone&token=deadc0de&distinct_id=1234&properties=%7B%22test%22:%224%22%7D", @"incorrect URL for the query items.");
}

#if TARGET_OS_IOS
//
// Updating the networking activity indicator should work if we are managing it
//
- (void)testNetworkActivityManagementEnabled {
    self.network.shouldManageNetworkActivityIndicator = YES;
    
    BOOL oldState = [UIApplication sharedApplication].isNetworkActivityIndicatorVisible;
    [self.network updateNetworkActivityIndicator:!oldState];
    dispatch_async(dispatch_get_main_queue(), ^{
        XCTAssert([UIApplication sharedApplication].networkActivityIndicatorVisible != oldState,
                  @"Updating the network activity indicator had no effect, even though we are managing it.");
    });
}

//
// Updating the networking activity indicator should not work if we are not managing it
//
- (void)testNetworkActivityManagementDisabled {
    self.network.shouldManageNetworkActivityIndicator = NO;
    
    BOOL currentState = [UIApplication sharedApplication].isNetworkActivityIndicatorVisible;
    [self.network updateNetworkActivityIndicator:!currentState];
    dispatch_async(dispatch_get_main_queue(), ^{
        XCTAssert([UIApplication sharedApplication].isNetworkActivityIndicatorVisible == currentState,
                  @"Updating the network activity indicator had an effect, even though we are not managing it.");
    });
}
#endif

#pragma mark Queue
//
// Flushing and empty event queue does nothing
//
- (void)testFlushEmptyEventQueue {
    [self.network flushEventQueue:[NSMutableArray array]];
}

//
// Flushing an empty people queue does nothing
//
- (void)testFlushEmptyPeopleQueue {
    [self.network flushPeopleQueue:[NSMutableArray array]];
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

- (void)testDateEncodingFromJSON {
    NSDate *fixedDate = [NSDate dateWithTimeIntervalSince1970:1400000000];
    NSArray *a = @[ @{ @"event": @"an event", @"properties": @{ @"eventdate": fixedDate } } ];
    NSString *json = [[NSString alloc] initWithData:[MPNetwork encodeArrayAsJSONData:a]
                                           encoding:NSUTF8StringEncoding];
    XCTAssert([json rangeOfString:@"\"eventdate\":\"2014-05-13T16:53:20.000Z\""].location != NSNotFound);
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
    XCTAssertGreaterThan(backOffDuration, 118, @"Requests should back off between 120s and 150s with two "
                         "consecutive failures.");
    XCTAssertLessThanOrEqual(backOffDuration, 152, @"Requests should back off between 120s and 150s with two "
                             "consecutive failures.");
    
    // Create a third failure to check the back off time
    [self.network handleNetworkResponse:badStatusResponse withError:nil];
    XCTAssert(self.network.consecutiveFailures == 3);
    
    backOffDuration = self.network.requestsDisabledUntilTime - [[NSDate date] timeIntervalSince1970];
    XCTAssertGreaterThan(backOffDuration, 238, @"Requests should back off between 240s and 270s with three "
                         "consecutive failures.");
    XCTAssertLessThanOrEqual(backOffDuration, 272, @"Requests should back off between 240s and 270s with three "
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
