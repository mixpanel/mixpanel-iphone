//
//  Mixpanel_WatchOS.m
//  HelloMixpanel
//
//  Created by Sam Green on 12/23/15.
//  Copyright © 2015 Mixpanel. All rights reserved.
//

#import "MixpanelWatchOS.h"
#import <WatchKit/WatchKit.h>
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
    
    NSMutableDictionary *mutableProperties = [properties mutableCopy];
    [mutableProperties addEntriesFromDictionary:[MixpanelWatchOS collectAutomaticProperties]];
    
    [self sendMessage:NSStringFromSelector(@selector(track:properties:))
       withParameters:@{ @"event": event, @"properties": [mutableProperties copy] }];
}

- (void)sendMessage:(NSString *)type withParameters:(nullable NSDictionary *)parameters {
    NSParameterAssert(type);
    
    if ([self.session isReachable]) {
        NSMutableDictionary *message = [parameters mutableCopy];
        message[@"$mp_message_type"] = type;
        
        // Send the event name and properties to the host app
        [self.session sendMessage:message
                     replyHandler:nil
                     errorHandler:^(NSError * _Nonnull error) {
                         MixpanelError(@"Error sending track: message to host application. Details: %@", [error localizedDescription]);
                     }];
    } else {
        MixpanelDebug(@"Host session is unreachable from watchOS.");
    }
}

+ (NSDictionary *)collectAutomaticProperties {
    NSMutableDictionary *mutableProperties = [NSMutableDictionary dictionaryWithCapacity:5];
    
    WKInterfaceDevice *device = [WKInterfaceDevice currentDevice];
    mutableProperties[@"$os"] = [device systemName];
    mutableProperties[@"$os_version"] = [device systemVersion];
    mutableProperties[@"$watch_model"] = [MixpanelWatchOS watchModel];
    
    CGSize screenSize = device.screenBounds.size;
    mutableProperties[@"$screen_width"] = @(screenSize.width);
    mutableProperties[@"$screen_height"] = @(screenSize.height);
    
    return [mutableProperties copy];
}

+ (NSString *)watchModel {
    static const CGFloat kAppleWatchScreenWidthSmall = 136.f;
    static const CGFloat kAppleWatchScreenWidthLarge = 152.f;
    
    CGFloat screenWidth = [WKInterfaceDevice currentDevice].screenBounds.size.width;
    if (screenWidth <= kAppleWatchScreenWidthSmall) {
        return @"Apple Watch 38mm";
    } else if (screenWidth <= kAppleWatchScreenWidthLarge) {
        return @"Apple Watch 42mm";
    }
    
    return @"Apple Watch";
}

@end
