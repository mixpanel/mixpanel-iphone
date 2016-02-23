//
//  CollectEverythingConstants.h
//  Mixpanel
//
//  Created by Sam Green on 3/22/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const kCollectEverythingEventName = @"$event";

#pragma mark - Top Level Keys
static NSString *const kActionKey = @"$event_action";
static NSString *const kTypeKey = @"$event_type";
static NSString *const kNotificationNameKey = @"$notification_name";
#pragma mark - Types
static NSString *const kTypeNotification = @"notification";
static NSString *const kTypeTouch = @"touch";
static NSString *const kTypeAction = @"action";
static NSString *const kTypeNavigation = @"navigation";

#pragma mark - Source Keys
static NSString *const kSourceTextKey = @"$event_source_text";
static NSString *const kSourceNameKey = @"$event_source_name";
static NSString *const kSourceClassKey = @"$event_source_class";
static NSString *const kSourceAccessibilityIdentifierKey = @"$event_source_accessibility_identifier";
static NSString *const kSourceAccessibilityLabelKey = @"$event_source_accessibility_label";

static NSString *const kSourceViewControllerClassKey = @"$event_source_view_controller_class";
static NSString *const kSourceViewControllerTitleKey = @"$event_source_view_controller_title";
static NSString *const kSourceViewControllerAccessibilityLabelKey = @"$event_source_view_controller_accessibility_label";

#pragma mark - Destination Keys
static NSString *const kDestinationTextKey = @"$event_destination_text";
static NSString *const kDestinationNameKey = @"$event_destination_name";
static NSString *const kDestinationClassKey = @"$event_destination_class";
static NSString *const kDestinationAccessibilityIdentifierKey = @"$event_destination_accessibility_identifier";
static NSString *const kDestinationAccessibilityLabelKey = @"$event_destination_accessibility_label";

static NSString *const kDestinationViewControllerClassKey = @"$event_destination_view_controller_class";
static NSString *const kDestinationViewControllerTitleKey = @"$event_destination_view_controller_title";
static NSString *const kDestinationViewControllerAccessibilityLabelKey = @"$event_destination_view_controller_accessibility_label";