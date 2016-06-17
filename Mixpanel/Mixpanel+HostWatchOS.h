//
//  Mixpanel+HostWatchOS.h
//  Mixpanel
//
//  Created by Sam Green on 4/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

@interface Mixpanel (HostWatchOS)

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message;

@end

NS_ASSUME_NONNULL_END
