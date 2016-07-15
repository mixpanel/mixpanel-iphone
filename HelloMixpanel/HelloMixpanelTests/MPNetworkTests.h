//
//  MPNetworkTests.h
//  HelloMixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPNetwork.h"

@interface MPNetworkTests : XCTestCase

@property (nonatomic, strong) MPNetwork *network;

@end

#pragma mark - Testable Interface
@interface MPNetwork ()

@property (nonatomic, strong) NSURL *serverURL;

@property (nonatomic) NSTimeInterval requestsDisabledUntilTime;
@property (nonatomic) NSUInteger consecutiveFailures;

- (BOOL)handleNetworkResponse:(NSHTTPURLResponse *)response withError:(NSError *)error;
- (NSURLRequest *)requestForEndpoint:(NSString *)endpoint withBody:(NSString *)body;

+ (NSTimeInterval)calculateBackOffTimeFromFailures:(NSUInteger)failureCount;
+ (NSTimeInterval)parseRetryAfterTime:(NSHTTPURLResponse *)response;
+ (BOOL)parseHTTPFailure:(NSHTTPURLResponse *)response withError:(NSError *)error;

+ (NSString *)encodeArrayForAPI:(NSArray *)array;
+ (NSData *)encodeArrayAsJSONData:(NSArray *)array;
+ (NSString *)encodeJSONDataAsBase64:(NSData *)data;

@end
