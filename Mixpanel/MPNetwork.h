//
//  MPNetwork.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNetwork : NSObject

@property (nonatomic) BOOL shouldManageNetworkActivityIndicator;
@property (nonatomic) BOOL useIPAddressForGeoLocation;

- (instancetype)initWithServerURL:(NSURL *)serverURL;

- (void)flushEventQueue:(NSArray *)events;
- (void)flushPeopleQueue:(NSArray *)people;

- (void)updateNetworkActivityIndicator:(BOOL)enabled;

- (NSURLRequest *)requestForEndpoint:(NSString *)endpoint
                        byHTTPMethod:(NSString *)method
                      withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems;

- (NSURLRequest *)requestForEndpoint:(NSString *)endpoint
                        byHTTPMethod:(NSString *)method
                             andBody:(NSString *)body;

@end
