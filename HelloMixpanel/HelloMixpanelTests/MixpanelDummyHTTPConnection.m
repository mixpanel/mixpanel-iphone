//
//  MixpanelDummyHTTPConnection.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 10/23/13.
//  Copyright (c) 2013 Mixpanel. All rights reserved.
//

#import "HTTPDataResponse.h"
#import "MixpanelDummyHTTPConnection.h"

@implementation MixpanelDummyHTTPConnection

static int requestCount;
static NSString *responseCode;

+ (void)initialize
{
    requestCount = 0;
    responseCode = @"1";
}

+(int) getRequestCount
{
    return requestCount;
}

+(void) setResponseCode:(NSString *)code
{
    responseCode = code;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    requestCount += 1;
    return [[HTTPDataResponse alloc] initWithData:[responseCode dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL) supportsMethod:(NSString *)method atPath:(NSString *)path
{
    return [super supportsMethod:method atPath:path] || [method isEqualToString:@"POST"];
}

@end
