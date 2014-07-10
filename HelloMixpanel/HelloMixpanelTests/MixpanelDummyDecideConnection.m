//
//  MixpanelDummyDecideConnection.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 9/7/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "MixpanelDummyDecideConnection.h"
#import "HTTPDataResponse.h"
#import "HTTPResponse.h"

@implementation MixpanelDummyDecideConnection

static int requestCount;

+ (void)initialize
{
    requestCount = 0;
}

+ (int)getRequestCount
{
    return requestCount;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    requestCount += 1;
    NSData * decideResponse = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"test_decide_response" withExtension:@"json"]];
    //decideResponse = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"serving response: %@", [[NSString alloc] initWithData:decideResponse encoding:NSUTF8StringEncoding]);
    return [[HTTPDataResponse alloc] initWithData:decideResponse];
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    return YES;
}

@end
