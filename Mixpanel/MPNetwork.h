//
//  MPNetwork.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPNetwork : NSObject

@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL shouldManageNetworkActivityIndicator;
@property (nonatomic) BOOL useIPAddressForGeoLocation;

- (void)setFlushInterval:(NSTimeInterval)flushInterval;

- (void)flushEventQueue:(NSArray *)events;
- (void)flushPeopleQueue:(NSArray *)people;

- (void)updateNetworkActivityIndicator:(BOOL)enabled;

@end
