//
//  MPNetworkPrivate.h
//  Mixpanel
//
//  Created by Sam Green on 6/17/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPNetwork.h"

@interface MPNetwork ()

@property (nonatomic, strong) NSURL *serverURL;

@property (nonatomic) NSTimeInterval requestsDisabledUntilTime;
@property (nonatomic) NSUInteger consecutiveFailures;

- (NSURLRequest *)requestForEndpoint:(NSString *)endpoint withBody:(NSString *)body;
+ (NSString *)encodeArrayForAPI:(NSArray *)array;

@end
