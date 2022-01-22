//
//  MPNetwork.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
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

- (void)flushEventQueue:(NSArray *)events;
- (void)flushPeopleQueue:(NSArray *)people;
- (void)flushGroupsQueue:(NSArray *)groups;

- (void)updateNetworkActivityIndicator:(BOOL)enabled;

- (NSURLRequest *)buildGetRequestForEndpoint:(MPNetworkEndpoint)endpoint
                              withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems;

- (NSURLRequest *)buildPostRequestForEndpoint:(MPNetworkEndpoint)endpoint
                               withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems
                                      andBody:(NSString *)body;

@end
