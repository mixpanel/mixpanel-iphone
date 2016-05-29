//
//  MixpanelDummy5XXHTTPConnection.m
//  HelloMixpanel
//
//  Created by Sam Green on 1/27/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MixpanelDummy5XXHTTPConnection.h"
#import "HTTPDataResponse.h"


@interface HTTPTimeoutResponse : HTTPDataResponse
@end

@implementation HTTPTimeoutResponse
- (NSInteger)status {
    return 503;
}
@end

@implementation MixpanelDummy5XXHTTPConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    return [[HTTPTimeoutResponse alloc] initWithData:[@"1" dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
