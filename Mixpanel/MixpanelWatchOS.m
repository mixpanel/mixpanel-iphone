//
//  Mixpanel_WatchOS.m
//  HelloMixpanel
//
//  Created by Sam Green on 12/23/15.
//  Copyright © 2015 Mixpanel. All rights reserved.
//

#import "MixpanelWatchOS.h"
#import "MPLogger.h"

@interface MixpanelWatchOS ()

/*!
 @property
 
 @abstract
 Setter for your default WCSession.
 
 @discussion
 This will allow Mixpanel to send tracked events to the host iOS application.
 */
@property (nonatomic, strong) WCSession *session;

@end

@implementation MixpanelWatchOS

static MixpanelWatchOS *sharedInstance = nil;

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        MixpanelDebug(@"warning sharedInstance called before sharedInstanceWithSession:");
    }
    return sharedInstance;
}

+ (instancetype)sharedInstanceWithSession:(WCSession *)session {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MixpanelWatchOS alloc] init];
        sharedInstance.session = session;
    });
    return sharedInstance;
}

- (void)track:(NSString *)event {
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(nullable NSDictionary *)properties {
    NSAssert(event != nil, @"Missing event name");
    
    // Ensure properties is not nil
    if (!properties) {
        properties = @{};
    }
    [self sendMessage:@"track" withParameters:@{ @"event": event, @"properties": properties }];
}

- (void)sendMessage:(NSString *)type withParameters:(nullable NSDictionary *)parameters {
    NSParameterAssert(type);
    
    if ([self.session isReachable]) {
        NSMutableDictionary *message = [parameters mutableCopy];
        message[@"$mp_message_type"] = type;
        
        // Send the event name and properties to the host app
        [self.session sendMessage:message
                     replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                         MixpanelDebug(@"Received reply from host for track: message. Details: %@", replyMessage);
                     }
                     errorHandler:^(NSError * _Nonnull error) {
                         MixpanelError(@"Error sending track: message to host application. Details: %@", [error localizedDescription]);
                     }];
    } else {
        MixpanelDebug(@"Host session is unreachable from watchOS.");
    }
}

@end
