//
//  Mixpanel+HostWatchOS.h
//  Mixpanel
//
//  Created by Sam Green on 4/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Mixpanel/Mixpanel.h>
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

@interface Mixpanel (HostWatchOS) <WCSessionDelegate>

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message;
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler;

@end

NS_ASSUME_NONNULL_END