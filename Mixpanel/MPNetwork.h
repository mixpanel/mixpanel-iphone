//
//  MPNetwork.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MPNetworkEndpoint) {
    MPNetworkEndpointTrack,
    MPNetworkEndpointEngage,
    MPNetworkEndpointDecide
};

@interface MPNetwork : NSObject

@property (nonatomic) BOOL shouldManageNetworkActivityIndicator;
@property (nonatomic) BOOL useIPAddressForGeoLocation;

- (instancetype)initWithServerURL:(NSURL *)serverURL;

- (void)flushEventQueue:(NSArray *)events;
- (void)flushPeopleQueue:(NSArray *)people;

- (void)updateNetworkActivityIndicator:(BOOL)enabled;

- (NSURLRequest *)buildGetRequestForEndpoint:(MPNetworkEndpoint)endpoint
                              withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems;

- (NSURLRequest *)buildPostRequestForEndpoint:(MPNetworkEndpoint)endpoint
                                      andBody:(NSString *)body;

@end
