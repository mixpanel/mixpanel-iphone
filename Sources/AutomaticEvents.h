//
//  AutomaticEvents.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import "MixpanelPeople.h"


@protocol TrackDelegate <NSObject>
- (void)track:(NSString *)event properties:(NSDictionary *)properties;
@end

@interface AutomaticEvents: NSObject
@property (atomic, weak) id<TrackDelegate> delegate;
@property (atomic, assign) UInt64 minimumSessionDuration;
@property (atomic, assign) UInt64 maximumSessionDuration;
- (void)initializeEvents:(MixpanelPeople *)peopleInstance apiToken:(NSString *)apiToken;

@end

#endif
