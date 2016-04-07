//
//  AutomaticEventsConstants.h
//  Mixpanel
//
//  Created by Sam Green on 3/22/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AutomaticEventMode) {
    AutomaticEventModeNone,
    AutomaticEventModeCount,
};

#pragma mark - Strings
static NSString *const kAutomaticEventName = @"$ios_event";