//
//  Mixpanel+HostWatchOS.m
//  Mixpanel
//
//  Created by Sam Green on 4/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel+HostWatchOS.h"
#import "MixpanelPrivate.h"

@implementation Mixpanel (HostWatchOS)

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message {
    if ([Mixpanel isMixpanelWatchMessage:message]) {
        [self track:message[@"event"] properties:message[@"properties"]];
    }
}

#pragma mark - Static Helpers
+ (BOOL)isMixpanelWatchMessage:(NSDictionary<NSString *, id> *)message {
    NSString *type = [Mixpanel messageTypeForWatchSessionMessage:message];
    return [type isEqualToString:NSStringFromSelector(@selector(track:properties:))];
}

+ (NSString *)messageTypeForWatchSessionMessage:(NSDictionary<NSString *, id> *)message {
    return [message objectForKey:@"$mp_message_type"];
}

@end
