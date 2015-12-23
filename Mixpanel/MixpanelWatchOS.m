//
//  Mixpanel_WatchOS.m
//  HelloMixpanel
//
//  Created by Sam Green on 12/23/15.
//  Copyright © 2015 Mixpanel. All rights reserved.
//

#import "MixpanelWatchOS.h"
#import "MPLogger.h"

@implementation MixpanelWatchOS

- (void)track:(NSString *)event {
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(nullable NSDictionary *)properties {
    NSAssert(event != nil, @"Missing event name");
    
    if ([self.session isReachable]) {
        
        // Ensure properties is not nil
        if (!properties) {
            properties = @{};
        }
        
        // Send the event name and properties to the host app
        NSDictionary *message = @{ @"messageType": @"mp_track", @"event": event, @"properties": properties };
        [self.session sendMessage:message
                     replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                         MixpanelDebug(@"Received reply from host for track: message. Details: %@", replyMessage);
                     }
                     errorHandler:^(NSError * _Nonnull error) {
                         MixpanelError(@"Error sending track: message to host application. Details: %@", [error localizedDescription]);
                     }];
    }
}

@end

#if !defined(MIXPANEL_WATCH_EXTENSION)
@implementation Mixpanel (WatchExtensions)

/** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message {
    if ([Mixpanel isValidWatchSessionMessage:message]) {
        [[Mixpanel sharedInstance] track:message[@"event"] properties:message[@"properties"]];
    }
}

/** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler {
    if ([Mixpanel isValidWatchSessionMessage:message]) {
        [[Mixpanel sharedInstance] track:message[@"event"] properties:message[@"properties"]];
        replyHandler(@{ @"success": @YES });
    } else {
        replyHandler(@{ @"success": @NO, @"message": @"Message is not a mixpanel message" });
    }
}

+ (BOOL)isValidWatchSessionMessage:(NSDictionary<NSString *, id> *)message {
    return [[message objectForKey:@"$mp_message_type"] boolValue];
}

@end
#endif
