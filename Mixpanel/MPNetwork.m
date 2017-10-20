//
//  MPNetwork.m
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MixpanelPrivate.h"
#import "MPLogger.h"
#import "MPNetwork.h"
#import "MPNetworkPrivate.h"
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif

#define MIXPANEL_NO_NETWORK_ACTIVITY_INDICATOR (defined(MIXPANEL_TVOS) || defined(MIXPANEL_WATCHOS) || defined(MIXPANEL_MACOS))

static const NSUInteger kBatchSize = 50;

@implementation MPNetwork

+ (NSURLSession *)sharedURLSession {
    static NSURLSession *sharedSession = nil;
    @synchronized(self) {
        if (sharedSession == nil) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 7.0;
            sharedSession = [NSURLSession sessionWithConfiguration:sessionConfig];
        }
    }
    return sharedSession;
}

- (instancetype)initWithServerURL:(NSURL *)serverURL mixpanel:(Mixpanel *)mixpanel {
    self = [super init];
    if (self) {
        self.serverURL = serverURL;
        self.shouldManageNetworkActivityIndicator = YES;
        self.useIPAddressForGeoLocation = YES;
        self.mixpanel = mixpanel;
    }
    return self;
}

#pragma mark - Flush
- (void)flushEventQueue:(NSMutableArray *)events {
    NSMutableArray *automaticEventsQueue;
    @synchronized (self.mixpanel) {
        automaticEventsQueue = [self orderAutomaticEvents:events];
    }
    [self flushQueue:events endpoint:MPNetworkEndpointTrack];
    @synchronized (self.mixpanel) {
        if (automaticEventsQueue) {
            [events addObjectsFromArray:automaticEventsQueue];
        }
    }
}

- (NSMutableArray *)orderAutomaticEvents:(NSMutableArray *)events {
    if (!self.mixpanel.automaticEventsEnabled || !self.mixpanel.automaticEventsEnabled.boolValue) {
        NSMutableArray *discardedItems = [NSMutableArray array];
        for (NSDictionary *e in events) {
            if ([e[@"event"] hasPrefix:@"$ae_"]) {
                [discardedItems addObject:e];
            }
        }
        [events removeObjectsInArray:discardedItems];
        if (!self.mixpanel.automaticEventsEnabled) {
            return discardedItems;
        }
    }
    return nil;
}

- (void)flushPeopleQueue:(NSMutableArray *)people {
    [self flushQueue:people endpoint:MPNetworkEndpointEngage];
}

- (void)flushQueue:(NSMutableArray *)queue endpoint:(MPNetworkEndpoint)endpoint {
    if ([[NSDate date] timeIntervalSince1970] < self.requestsDisabledUntilTime) {
        MPLogDebug(@"Attempted to flush to %lu, when we still have a timeout. Ignoring flush.", endpoint);
        return;
    }

    NSMutableArray *queueCopyForFlushing;

    Mixpanel *mixpanel = self.mixpanel;
    @synchronized (mixpanel) {
        queueCopyForFlushing = [queue mutableCopy];
    }
    
    while (queueCopyForFlushing.count > 0) {
        NSUInteger batchSize = MIN(queueCopyForFlushing.count, kBatchSize);
        NSArray *batch = [queueCopyForFlushing subarrayWithRange:NSMakeRange(0, batchSize)];
        
        NSString *requestData = [MPNetwork encodeArrayForAPI:batch];
        NSString *postBody = [NSString stringWithFormat:@"ip=%d&data=%@", self.useIPAddressForGeoLocation, requestData];
        MPLogDebug(@"%@ flushing %lu of %lu to %lu: %@", self, (unsigned long)batch.count, (unsigned long)queue.count, endpoint, queueCopyForFlushing);
        NSURLRequest *request = [self buildPostRequestForEndpoint:endpoint andBody:postBody];
        
        [self updateNetworkActivityIndicator:YES];
        
        __block BOOL didFail = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[[MPNetwork sharedURLSession] dataTaskWithRequest:request completionHandler:^(NSData *responseData,
                                                                  NSURLResponse *urlResponse,
                                                                  NSError *error) {
            [self updateNetworkActivityIndicator:NO];
            
            BOOL success = [self handleNetworkResponse:(NSHTTPURLResponse *)urlResponse withError:error];
            if (error || !success) {
                MPLogError(@"%@ network failure: %@", self, error);
                didFail = YES;
            } else {
                NSString *response = [[NSString alloc] initWithData:responseData
                                                           encoding:NSUTF8StringEncoding];
                if ([response intValue] == 0) {
                    MPLogInfo(@"%@ %lu api rejected some items", self, endpoint);
                }
            }
            
            dispatch_semaphore_signal(semaphore);
        }] resume];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        if (didFail) {
            break;
        }

        @synchronized (mixpanel) {
            for (NSDictionary *event in batch) {
                NSUInteger index = [queueCopyForFlushing indexOfObjectIdenticalTo:event];
                if (index != NSNotFound) {
                    [queueCopyForFlushing removeObjectAtIndex:index];
                }
                index = [queue indexOfObjectIdenticalTo:event];
                if (index != NSNotFound) {
                    [queue removeObjectAtIndex:index];
                }
            }
        }
    }
}

- (BOOL)handleNetworkResponse:(NSHTTPURLResponse *)response withError:(NSError *)error {
    MPLogDebug(@"HTTP Response: %@", response.allHeaderFields);
    MPLogDebug(@"HTTP Error: %@", error.localizedDescription);
    
    BOOL failed = [MPNetwork parseHTTPFailure:response withError:error];
    if (failed) {
        MPLogDebug(@"Consecutive network failures: %lu", self.consecutiveFailures);
        self.consecutiveFailures++;
    } else {
        MPLogDebug(@"Consecutive network failures reset to 0");
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
    
    MPLogDebug(@"Retry backoff time: %.2f - %@", retryTime, retryDate);
    
    return !failed;
}

#pragma mark - Helpers
+ (NSArray<NSURLQueryItem *> *)buildDecideQueryForProperties:(NSDictionary *)properties
                                              withDistinctID:(NSString *)distinctID
                                                    andToken:(NSString *)token {
    NSURLQueryItem *itemVersion = [NSURLQueryItem queryItemWithName:@"version" value:@"1"];
    NSURLQueryItem *itemLib = [NSURLQueryItem queryItemWithName:@"lib" value:@"iphone"];
    NSURLQueryItem *itemToken = [NSURLQueryItem queryItemWithName:@"token" value:token];
    NSURLQueryItem *itemDistinctID = [NSURLQueryItem queryItemWithName:@"distinct_id" value:distinctID];

    // Convert properties dictionary to a string
    NSData *propertiesData = [NSJSONSerialization dataWithJSONObject:properties
                                                             options:0
                                                               error:NULL];
    NSString *propertiesString = [[NSString alloc] initWithData:propertiesData
                                                       encoding:NSUTF8StringEncoding];
    NSURLQueryItem *itemProperties = [NSURLQueryItem queryItemWithName:@"properties" value:propertiesString];
    
    return @[ itemVersion, itemLib, itemToken, itemDistinctID, itemProperties ];
}

+ (NSString *)pathForEndpoint:(MPNetworkEndpoint)endpoint {
    static NSDictionary *endPointToPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endPointToPath = @{ @(MPNetworkEndpointTrack): @"/track/",
                            @(MPNetworkEndpointEngage): @"/engage/",
                            @(MPNetworkEndpointDecide): @"/decide" };
    });
    NSNumber *key = @(endpoint);
    return endPointToPath[key];
}

- (NSURLRequest *)buildGetRequestForEndpoint:(MPNetworkEndpoint)endpoint
                              withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems {
    return [self buildRequestForEndpoint:[MPNetwork pathForEndpoint:endpoint]
                            byHTTPMethod:@"GET"
                          withQueryItems:queryItems
                                 andBody:nil];
}

- (NSURLRequest *)buildPostRequestForEndpoint:(MPNetworkEndpoint)endpoint
                                      andBody:(NSString *)body {
    return [self buildRequestForEndpoint:[MPNetwork pathForEndpoint:endpoint]
                            byHTTPMethod:@"POST"
                          withQueryItems:nil
                                 andBody:body];
}

- (NSURLRequest *)buildRequestForEndpoint:(NSString *)endpoint
                             byHTTPMethod:(NSString *)method
                           withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems
                                  andBody:(NSString *)body {
    // Build URL from path and query items
    NSURL *urlWithEndpoint = [self.serverURL URLByAppendingPathComponent:endpoint];
    NSURLComponents *components = [NSURLComponents componentsWithURL:urlWithEndpoint
                                             resolvingAgainstBaseURL:YES];
    if (queryItems) {
        components.queryItems = queryItems;
    }

    // NSURLComponents/NSURLQueryItem doesn't encode + as %2B, and then the + is interpreted as a space on servers
    components.percentEncodedQuery = [components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];

    // Build request from URL
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:method];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    MPLogDebug(@"%@ http request: %@?%@", self, request, body);
    
    return [request copy];
}

+ (NSString *)encodeArrayForAPI:(NSArray *)array {
    NSData *data = [MPNetwork encodeArrayAsJSONData:array];
    return [MPNetwork encodeJSONDataAsBase64:data];
}

+ (NSData *)encodeArrayAsJSONData:(NSArray *)array {
    NSError *error = NULL;
    NSData *data = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:[self convertFoundationTypesToJSON:array]
                                               options:(NSJSONWritingOptions)0
                                                 error:&error];
    }
    @catch (NSException *exception) {
        MPLogError(@"exception encoding api data: %@", exception);
    }
    
    if (error) {
        MPLogError(@"error encoding api data: %@", error);
    }
    
    return data;
}

+ (NSString *)encodeJSONDataAsBase64:(NSData *)data {
    return [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

+ (id)convertFoundationTypesToJSON:(id)obj {
    // valid json types
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class] || [obj isKindOfClass:NSNull.class]) {
        return obj;
    }
    
    if ([obj isKindOfClass:NSDate.class]) {
        return [[self dateFormatter] stringFromDate:obj];
    } else if ([obj isKindOfClass:NSURL.class]) {
        return [obj absoluteString];
    }
    
    // recurse on containers
    if ([obj isKindOfClass:NSArray.class]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self convertFoundationTypesToJSON:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey = key;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                MPLogWarning(@"%@ property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            }
            id v = [self convertFoundationTypesToJSON:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    
    // default to sending the object's description
    NSString *s = [obj description];
    MPLogWarning(@"%@ property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return formatter;
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
#if !MIXPANEL_NO_NETWORK_ACTIVITY_INDICATOR
    if (![Mixpanel isAppExtension]) {
        if (self.shouldManageNetworkActivityIndicator) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Mixpanel sharedUIApplication].networkActivityIndicatorVisible = enabled;
            });
        }
    }
#endif
}

@end
