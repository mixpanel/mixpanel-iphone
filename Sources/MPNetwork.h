//
//  MPNetwork.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Mixpanel;

typedef NS_ENUM(NSUInteger, MPNetworkEndpoint) {
    MPNetworkEndpointTrack,
    MPNetworkEndpointEngage,
    MPNetworkEndpointDecide,
    MPNetworkEndpointGroups
};

@interface MPNetwork : NSObject

@property (nonatomic) BOOL shouldManageNetworkActivityIndicator;
@property (nonatomic) BOOL useIPAddressForGeoLocation;

- (instancetype)initWithServerURL:(NSURL *)serverURL mixpanel:(Mixpanel *)mixpanel;

- (void)flushEventQueue:(NSMutableArray *)events;
- (void)flushPeopleQueue:(NSMutableArray *)people;
- (void)flushGroupsQueue:(NSMutableArray *)groups;

- (void)updateNetworkActivityIndicator:(BOOL)enabled;

- (NSURLRequest *)buildGetRequestForEndpoint:(MPNetworkEndpoint)endpoint
                              withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems;

- (NSURLRequest *)buildPostRequestForEndpoint:(MPNetworkEndpoint)endpoint
                                      andBody:(NSString *)body;

@end
