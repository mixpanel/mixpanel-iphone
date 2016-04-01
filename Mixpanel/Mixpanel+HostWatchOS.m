//
//  Mixpanel+HostWatchOS.m
//  Mixpanel
//
//  Created by Sam Green on 4/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel+HostWatchOS.h"

@implementation Mixpanel (HostWatchOS)

/** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message {
    NSString *messageType = [Mixpanel messageTypeForWatchSessionMessage:message];
    if (messageType) {
        if ([messageType isEqualToString:@"track"]) {
            [self track:message[@"event"] properties:message[@"properties"]];
        }
    }
}

+ (NSString *)messageTypeForWatchSessionMessage:(NSDictionary<NSString *, id> *)message {
    return [message objectForKey:@"$mp_message_type"];
}

@end
