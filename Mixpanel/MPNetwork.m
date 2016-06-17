//
//  MPNetwork.m
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPNetwork.h"
#import "MPLogger.h"
#import <UIKit/UIKit.h>

static const NSUInteger kBatchSize = 50;

@interface MPNetwork ()

@property (nonatomic, strong) NSURL *serverURL;

@property (nonatomic) NSTimeInterval requestsDisabledUntilTime;
@property (nonatomic) NSUInteger consecutiveFailures;

@end

@implementation MPNetwork

- (instancetype)initWithServerURL:(NSURL *)serverURL {
    self = [super init];
    if (self) {
        self.serverURL = serverURL;
        self.enabled = YES;
        self.shouldManageNetworkActivityIndicator = YES;
        self.useIPAddressForGeoLocation = YES;
    }
    return self;
}

#pragma mark - Flush
- (void)flushEventQueue:(NSMutableArray *)events {
    [self flushQueue:events endpoint:@"/track/"];
}

- (void)flushPeopleQueue:(NSMutableArray *)people {
    [self flushQueue:people endpoint:@"/engage/"];
}

- (void)flushQueue:(NSMutableArray *)queue endpoint:(NSString *)endpoint {
    if ([[NSDate date] timeIntervalSince1970] < self.requestsDisabledUntilTime) {
        MixpanelDebug(@"Attempted to flush to %@, when we still have a timeout. Ignoring flush.", endpoint);
        return;
    }
    
    if (!self.enabled) return;
    
    while (queue.count > 0) {
        NSUInteger batchSize = MIN(queue.count, kBatchSize);
        NSArray *batch = [queue subarrayWithRange:NSMakeRange(0, batchSize)];
        
        NSString *requestData = [MPNetwork encodeArrayForAPI:batch];
        NSString *postBody = [NSString stringWithFormat:@"ip=%d&data=%@", self.useIPAddressForGeoLocation, requestData];
        MixpanelDebug(@"%@ flushing %lu of %lu to %@: %@", self, (unsigned long)batch.count, (unsigned long)queue.count, endpoint, queue);
        NSURLRequest *request = [self requestForEndpoint:endpoint withBody:postBody];
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
        if (response.intValue == 0) {
            MixpanelError(@"%@ %@ api rejected some items", self, endpoint);
        }
        
        [queue removeObjectsInArray:batch];
    }
}

- (BOOL)handleNetworkResponse:(NSHTTPURLResponse *)response withError:(NSError *)error {
    MixpanelDebug(@"HTTP Response: %@", response.allHeaderFields);
    MixpanelDebug(@"HTTP Error: %@", error.localizedDescription);
    
    BOOL failed = [MPNetwork parseHTTPFailure:response withError:error];
    if (failed) {
        MixpanelDebug(@"Consecutive network failures: %lu", self.consecutiveFailures);
        self.consecutiveFailures++;
    } else {
        MixpanelDebug(@"Consecutive network failures reset to 0");
        self.consecutiveFailures = 0;
    }
    
    // Did the server response with an HTTP `Retry-After` header?
    NSTimeInterval retryTime = [MPNetwork parseRetryAfterTime:response];
    if (self.consecutiveFailures >= 2) {
        
        // Take the larger of exponential back off and server provided `Retry-After`
        retryTime = MAX(retryTime, [MPNetwork calculateBackOffTimeFromFailures:self.consecutiveFailures]);
    }
    
    NSDate *retryDate = [NSDate dateWithTimeIntervalSinceNow:retryTime];
    self.requestsDisabledUntilTime = [retryDate timeIntervalSince1970];
    
    MixpanelDebug(@"Retry backoff time: %.2f - %@", retryTime, retryDate);
    
    return !failed;
}

#pragma mark - Helpers
- (NSURLRequest *)requestForEndpoint:(NSString *)endpoint withBody:(NSString *)body {
    NSURL *URL = [self.serverURL URLByAppendingPathComponent:endpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    MixpanelDebug(@"%@ http request: %@?%@", self, URL, body);
    
    return request;
}

+ (NSString *)encodeArrayForAPI:(NSArray *)array {
    NSData *data = [MPNetwork encodeArrayAsJSONData:array];
    return [MPNetwork encodeJSONDataAsBase64:data];
}

+ (NSData *)encodeArrayAsJSONData:(NSArray *)array {
    if (![NSJSONSerialization isValidJSONObject:array]) return nil;
    
    NSError *error = NULL;
    NSData *data = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:array
                                               options:(NSJSONWritingOptions)0
                                                 error:&error];
    }
    @catch (NSException *exception) {
        MixpanelError(@"exception encoding api data: %@", exception);
    }
    
    if (error) {
        MixpanelError(@"error encoding api data: %@", error);
    }
    
    return data;
}

+ (NSString *)encodeJSONDataAsBase64:(NSData *)data {
    return [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

+ (NSTimeInterval)calculateBackOffTimeFromFailures:(NSUInteger)failureCount {
    NSTimeInterval time = pow(2.0, failureCount - 1) * 60 + arc4random_uniform(30);
    return MIN(MAX(60, time), 600);
}

+ (NSTimeInterval)parseRetryAfterTime:(NSHTTPURLResponse *)response {
    return [response.allHeaderFields[@"Retry-After"] doubleValue];
}

+ (BOOL)parseHTTPFailure:(NSHTTPURLResponse *)response withError:(NSError *)error {
    return (error != nil || (500 <= response.statusCode && response.statusCode <= 599));
}

- (void)updateNetworkActivityIndicator:(BOOL)enabled {
#if !defined(MIXPANEL_APP_EXTENSION)
    if (self.shouldManageNetworkActivityIndicator) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = enabled;
    }
#endif
}

@end
