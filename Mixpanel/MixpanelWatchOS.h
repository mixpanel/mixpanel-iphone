//
//  Mixpanel_WatchOS.h
//  HelloMixpanel
//
//  Created by Sam Green on 12/23/15.
//  Copyright © 2015 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "Mixpanel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MixpanelWatchOS : NSObject

/*!
 @property
 
 @abstract
 Setter for your default WCSession.
 
 @discussion
 This will allow Mixpanel to send tracked events to the host iOS application.
 */
@property (nonatomic, strong) WCSession *session;

/*!
 @method
 
 @abstract
 Tracks an event.
 
 @param event           event name
 */
- (void)track:(NSString *)event;

/*!
 @method
 
 @abstract
 Tracks an event with properties.
 
 @discussion
 Properties will allow you to segment your events in your Mixpanel reports.
 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects. If the event is being timed, the timer will
 stop and be added as a property.
 
 @param event           event name
 @param properties      properties dictionary
 */
- (void)track:(NSString *)event properties:(nullable NSDictionary *)properties;

@end

@interface Mixpanel (WatchExtensions) <WCSessionDelegate>

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message;
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler;

@end

NS_ASSUME_NONNULL_END
