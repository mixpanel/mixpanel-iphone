//
//  MixpanelDummyRetryAfterConnection.m
//  HelloMixpanel
//
//  Created by Sam Green on 1/27/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelDummyRetryAfterConnection.h"
#import "HTTPDataResponse.h"

@interface HTTPRetryAfterResponse : HTTPDataResponse
@end

@implementation HTTPRetryAfterResponse

- (NSDictionary *)httpHeaders {
    return @{ @"Retry-After": @"60" };
}

@end

@implementation MixpanelDummyRetryAfterConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    return [[HTTPRetryAfterResponse alloc] initWithData:[@"0" dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
