#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MixpanelPeople.h"
#import "MixpanelType.h"
#import "MixpanelGroup.h"
#import "MixpanelIdentity.h"


#if TARGET_OS_WATCH
#define MIXPANEL_FLUSH_IMMEDIATELY 1
#define MIXPANEL_NO_APP_LIFECYCLE_SUPPORT 1
#endif

#if TARGET_OS_WATCH || TARGET_OS_OSX
#define MIXPANEL_NO_UIAPPLICATION_ACCESS 1
#endif

#if TARGET_OS_TV || TARGET_OS_WATCH || TARGET_OS_OSX
#define MIXPANEL_NO_REACHABILITY_SUPPORT 1
#define MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT 1
#endif

@class    MixpanelPersistence;
@class    MixpanelPeople;
@class    MixpanelGroup;
@class    MixpanelIdentity;
@protocol MixpanelDelegate;

NS_ASSUME_NONNULL_BEGIN

/*!
 Mixpanel API.

 The primary interface for integrating Mixpanel with your app.

 Use the Mixpanel class to set up your project and track events in Mixpanel
 Engagement. It now also includes a <code>people</code> property for accessing
 the Mixpanel People API.

 <pre>
 // Initialize the API
 Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"YOUR API TOKEN"];

 // Track an event in Mixpanel Engagement
 [mixpanel track:@"Button Clicked"];

 // Set properties on a user in Mixpanel People
 [mixpanel identify:@"CURRENT USER DISTINCT ID"];
 [mixpanel.people set:@"Plan" to:@"Premium"];
 </pre>

 For more advanced usage, please see the <a
 href="https://mixpanel.com/docs/integration-libraries/iphone">Mixpanel iPhone
 Library Guide</a>.
 */
@interface Mixpanel : NSObject

#pragma mark Properties

@property (atomic, readonly, strong) MixpanelPersistence *persistence;

/*!
 Accessor to the Mixpanel People API object.

 See the documentation for MixpanelDelegate below for more information.
 */
@property (atomic, readonly, strong) MixpanelPeople *people;

/*!
 The distinct ID of the current user.

 A distinct ID is a string that uniquely identifies one of your users. By default,
 we'll use the device's advertisingIdentifier UUIDString, if that is not available
 we'll use the device's identifierForVendor UUIDString, and finally if that
 is not available we will generate a new random UUIDString. To change the
 current distinct ID, use the <code>identify:</code> method.

 On a hierarchical groups project Mixpanel builds the distinct ID from the company and
 the user, so once both are known this returns <code>$company:{companyId}|$user:{userId}</code>.
 Until a company is known, Mixpanel keeps the user under the device, so this returns
 <code>$device:</code> followed by the device ID. The combined form is Mixpanel's own format,
 and it cannot be parsed back when either ID contains <code>|</code>. Events never send it:
 once both are known, events omit <code>distinct_id</code> and carry <code>$user_id</code> and
 <code>$company_id</code> instead.

 Don't use this on a hierarchical groups project. Prefer <code>identity</code>, whose user,
 company and device IDs every Mixpanel SDK accepts directly.
 */
@property (atomic, readonly, copy) NSString *distinctId;

/*!
 Who events are currently attributed to: the identified user, their company on a
 hierarchical groups project, and the device ID (<code>anonymousId</code>).

 Before identifying, the user ID is nil and only the device ID is set. The company is nil
 unless hierarchical groups is enabled. The returned identity is a snapshot and does not
 change after a later identify or <code>reset</code>.
 */
@property (atomic, readonly, strong) MixpanelIdentity *identity;

/*!
 Whether this instance tracks for a project that uses hierarchical groups.

 Set when the instance is created, with an initializer that takes
 <code>hierarchicalGroups</code>, and fixed for the life of the instance. Defaults to NO,
 which behaves exactly as before. See
 <code>sharedInstanceWithToken:trackAutomaticEvents:hierarchicalGroups:</code>.
 */
@property (atomic, readonly) BOOL hierarchicalGroups;

/*!
 The default anonymous Id / distinct Id  given to the events before identify.

 A default distinct ID is a string that uniquely identifies the anonymous activity.
 By default, we'll use the device's advertisingIdentifier UUIDString, if that is not
 available we'll use the device's identifierForVendor UUIDString, and finally if that
 is not available we will generate a new random UUIDString.
 */
@property (atomic, readonly, copy) NSString *anonymousId;

/*!
  The user ID with which <code>identify:</code> is called with.

  This is null until <code>identify:</code> is called and is set to the id
  with which identify is called with.
 */
@property (atomic, readonly, copy) NSString *userId;

/*!
 The alias of the current user.

 An alias is another string that uniquely identifies one of your users. Typically,
 this is the user ID from your database. By using an alias you can link pre- and
 post-sign up activity as well as cross-platform activity under one distinct ID.
 To set the alias use the <code>createAlias:forDistinctID:</code> method.
 */
@property (atomic, readonly, copy) NSString *alias;

/*!
 A flag which says if a distinctId is already in peristence from old sdk
  Defaults to NO.
 */
@property (nonatomic, assign) BOOL hadPersistedDistinctId;

/*!
 The base URL used for Mixpanel API requests.

 Useful if you need to proxy Mixpanel requests. Defaults to
 https://api.mixpanel.com.
 */
@property (nonatomic, copy) NSString *serverURL;

/*!
 Flush timer's interval.

 Setting a flush interval of 0 will turn off the flush timer.
 */
@property (atomic) NSUInteger flushInterval;

/*!
 Control whether the library should flush data to Mixpanel when the app
 enters the background.

 Defaults to YES. Only affects apps targeted at iOS 4.0, when background
 task support was introduced, and later.
 */
@property (atomic) BOOL flushOnBackground;

/*!
 Controls whether to show spinning network activity indicator when flushing
 data to the Mixpanel servers.

 Defaults to YES.
 */
@property (atomic) BOOL shouldManageNetworkActivityIndicator;


/*!
 Controls whether to automatically send the client IP Address as part of
 event tracking. With an IP address, geo-location is possible down to neighborhoods
 within a city, although the Mixpanel Dashboard will just show you city level location
 specificity. For privacy reasons, you may be in a situation where you need to forego
 effectively having access to such granular location information via the IP Address.

 Defaults to YES.
 */
@property (atomic) BOOL useIPAddressForGeoLocation;

/*!
 Controls whether or not to use a unique device identifier for the Mixpanel Distinct ID
 
 Defaults to NO
 */
@property (atomic) BOOL useUniqueDistinctId;

/*!
 This allows enabling or disabling collecting common mobile events
 */
@property (nonatomic) BOOL trackAutomaticEventsEnabled;

/*!
 Controls whether to enable the run time debug logging at all levels. Note that the
 Mixpanel SDK uses Apple System Logging to forward log messages to `STDERR`, this also
 means that mixpanel logs are segmented by log level. Settings this to `YES` will enable
 Mixpanel logging at the following levels:

   * Error - Something has failed
   * Warning - Something is amiss and might fail if not corrected
   * Info - The lowest priority that is normally logged, purely informational in nature
   * Debug - Information useful only to developers, and normally not logged.


 Defaults to NO.
 */
@property (atomic) BOOL enableLogging;

#if !MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT
/*!
 The minimum session duration (ms) that is tracked in automatic events.

 The default value is 10000 (10 seconds).
 */
@property (atomic) UInt64 minimumSessionDuration;

/*!
 The maximum session duration (ms) that is tracked in automatic events.

 The default value is UINT64_MAX (no maximum session duration).
 */
@property (atomic) UInt64 maximumSessionDuration;
#endif

/*!
 The a MixpanelDelegate object that can be used to assert fine-grain control
 over Mixpanel network activity.

 Using a delegate is optional. See the documentation for MixpanelDelegate
 below for more information.
 */
@property (atomic, weak) id<MixpanelDelegate> delegate; // allows fine grain control over uploading (optional)

#pragma mark Tracking

/*!
 Returns (and creates, if needed) a singleton instance of the API.

 This method will return a singleton instance of the <code>Mixpanel</code> class for
 you using the given project token. If an instance does not exist, this method will create
 one using <code>initWithToken:flushInterval:</code>. If you only have one
 instance in your project, you can use <code>sharedInstance</code> to retrieve it.

 <pre>
 [Mixpanel sharedInstance] track:@"Something Happened"]];
 </pre>

 If you are going to use this singleton approach,
 <code>sharedInstanceWithToken:</code> <b>must be the first call</b> to the
 <code>Mixpanel</code> class, since it performs important initializations to
 the API.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents;

/*!
 Initializes a singleton instance of the API, uses it to set whether or not to opt out tracking for
 GDPR compliance, and then returns it.

 With the optOutTrackingByDefault parameter, Mixpanel tracking can be opted out by default.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param optOutTrackingByDefault  whether or not to be opted out from tracking by default

 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents optOutTrackingByDefault:(BOOL)optOutTrackingByDefault;

/*!
 Initializes a singleton instance of the API, uses it to track crashes, and then returns it.

 With the trackCrashes parameter, Mixpanel can track crashes.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param trackCrashes    whether or not to track crashes in Mixpanel. may want to disable if you're seeing
 issues with your crash reporting for either signals or exceptions
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes;

/*!
 Initializes a singleton instance of the API, using the unique device identifier for distinct_id and then returns it.

 With the useUniqueDistinctId parameter, Mixpanel will use a unique device id for distinct_id.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param useUniqueDistinctId    whether or not to use the unique device identifier as the distinct_id
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents useUniqueDistinctId:(BOOL)useUniqueDistinctId;

/*!
 Initializes a singleton instance of the API, uses it to track crashes, set whether or not to opt out tracking for
 GDPR compliance, and then returns it.
 
 With the optOutTrackingByDefault parameter, Mixpanel tracking can be opted out by default.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param trackCrashes    whether or not to track crashes in Mixpanel. may want to disable if you're seeing
 issues with your crash reporting for either signals or exceptions
 @param optOutTrackingByDefault  whether or not to be opted out from tracking by default
 @param useUniqueDistinctId whether or not to use the unique device identifier as the distinct_id
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes optOutTrackingByDefault:(BOOL)optOutTrackingByDefault useUniqueDistinctId:(BOOL)useUniqueDistinctId;

/*!
 Initializes a singleton instance of the API for a project that uses hierarchical groups,
 and then returns it.

 Set <code>hierarchicalGroups</code> to match the project from the first launch; it is not
 meant to be changed for an existing install. On a hierarchical groups project Mixpanel builds
 the user's distinct ID from <code>$company_id</code> and <code>$user_id</code>, so the company
 is part of the user's identity. When enabled:

 <ul>
 <li>Identify with <code>identifyWithIdentity:</code>. Every event then carries
 <code>$company_id</code> beside <code>$user_id</code> and <code>$device_id</code>.</li>
 <li><code>$company_id</code> is the identified company. An event's <code>$company_id</code> is
 always the identified one, replacing a different value passed to <code>track</code> or
 <code>trackWithGroups</code> with a warning; before a company is identified a passed
 <code>$company_id</code> is removed with a warning and the event is still sent. Super property
 and group membership calls that name <code>$company_id</code> are refused whole with an error
 log.</li>
 <li><code>people</code> updates are sent to <code>/groups</code> as the <code>$user_id</code>
 group profile within the company. Updates made before identifying are queued and sent, in
 order, for the user and company of the next <code>identifyWithIdentity:</code>; <code>reset</code>
 clears them. <code>/groups</code> has no <code>$add</code>, <code>$append</code> or
 <code>$merge</code>, so increment, append, merge and trackCharge are dropped with an error log.</li>
 <li>Updates to a <code>$company_id</code> group profile carry that company as
 <code>$company_id</code>. Other group profile updates carry the current <code>$company_id</code>,
 and are dropped until a company is known.</li>
 </ul>

 If an instance already exists for the token, it is returned unchanged.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param hierarchicalGroups  whether the project uses hierarchical groups
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents hierarchicalGroups:(BOOL)hierarchicalGroups;

/*!
 Initializes a singleton instance of the API with every option, and then returns it.

 See <code>sharedInstanceWithToken:trackAutomaticEvents:hierarchicalGroups:</code> for what
 <code>hierarchicalGroups</code> changes. If an instance already exists for the token, it is
 returned unchanged.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param trackCrashes    whether or not to track crashes in Mixpanel
 @param optOutTrackingByDefault  whether or not to be opted out from tracking by default
 @param useUniqueDistinctId whether or not to use the unique device identifier as the distinct_id
 @param hierarchicalGroups  whether the project uses hierarchical groups
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents trackCrashes:(BOOL)trackCrashes optOutTrackingByDefault:(BOOL)optOutTrackingByDefault useUniqueDistinctId:(BOOL)useUniqueDistinctId hierarchicalGroups:(BOOL)hierarchicalGroups;

/*!
 Returns a previously instantiated singleton instance of the API.

 The API must be initialized with <code>sharedInstanceWithToken:</code> or
 <code>initWithToken:flushInterval</code> before calling this class method.
 This method will return <code>nil</code> if there are no instances created. If there is more than
 one instace, it will return the first one that was created by using <code>sharedInstanceWithToken:</code>
 or <code>initWithToken:flushInterval:</code>.
 */
+ (nullable Mixpanel *)sharedInstance;

/*!
 Initializes an instance of the API with the given project token. This also sets
 it as a shared instance so you can use <code>sharedInstance</code> or
 <code>sharedInstanceWithToken:</code> to retrieve this object later.

 Creates and initializes a new API object. See also <code>sharedInstanceWithToken:</code>.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param flushInterval   interval to run background flushing
 @param trackCrashes    whether or not to track crashes in Mixpanel. may want to disable if you're seeing
                        issues with your crash reporting for either signals or exceptions
 @param useUniqueDistinctId whether or not to use the unique device identifier as the distinct_id
 */
- (instancetype)initWithToken:(NSString *)apiToken
         trackAutomaticEvents:(BOOL)trackAutomaticEvents
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
          useUniqueDistinctId:(BOOL)useUniqueDistinctId;

/*!
 Initializes an instance of the API with the given project token. This also sets
 it as a shared instance so you can use <code>sharedInstance</code> or
 <code>sharedInstanceWithToken:</code> to retrieve this object later.

 Creates and initializes a new API object. See also <code>sharedInstanceWithToken:</code>.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param flushInterval   interval to run background flushing
 */
- (instancetype)initWithToken:(NSString *)apiToken trackAutomaticEvents:(BOOL)trackAutomaticEvents andFlushInterval:(NSUInteger)flushInterval;

/*!
 Initializes an instance of the API with the given project token and every option. This also
 sets it as a shared instance so you can use <code>sharedInstance</code> or
 <code>sharedInstanceWithToken:</code> to retrieve this object later.

 See <code>sharedInstanceWithToken:trackAutomaticEvents:hierarchicalGroups:</code> for what
 <code>hierarchicalGroups</code> changes.

 @param apiToken        your project token
 @param trackAutomaticEvents    whether or not to track automatic events
 @param flushInterval   interval to run background flushing
 @param trackCrashes    whether or not to track crashes in Mixpanel
 @param optOutTrackingByDefault  whether or not to be opted out from tracking by default
 @param useUniqueDistinctId whether or not to use the unique device identifier as the distinct_id
 @param hierarchicalGroups  whether the project uses hierarchical groups
 */
- (instancetype)initWithToken:(NSString *)apiToken
         trackAutomaticEvents:(BOOL)trackAutomaticEvents
                flushInterval:(NSUInteger)flushInterval
                 trackCrashes:(BOOL)trackCrashes
      optOutTrackingByDefault:(BOOL)optOutTrackingByDefault
          useUniqueDistinctId:(BOOL)useUniqueDistinctId
           hierarchicalGroups:(BOOL)hierarchicalGroups;

/*!
 Sets the distinct ID of the current user.

 Mixpanel uses a randomly generated persistent UUID as the default local distinct ID.

 If you want to  use a unique persistent UUID, you can define the
 <code>MIXPANEL_UNIQUE_DISTINCT_ID</code>  preprocessor flag in your build settings.
 It then uses the IFV String (`UIDevice.current().identifierForVendor`) as the default local distinct ID.
 This ID will identify a user across all apps by the same vendor, but cannot be used to link the same
 user across apps from different vendors. If we are unable to get an IFV, we will fall back to generating
 a random persistent UUID.

 For tracking events, you do not need to call <code>identify:</code>.
 However, <b>Mixpanel User profiles always require an
 explicit call to <code>identify:</code></b>. If calls are made to
 <code>set:</code>, <code>increment</code> or other <code>MixpanelPeople</code>
 methods prior to calling <code>identify:</code>, then they are queued up and
 flushed once <code>identify:</code> is called.

 If you'd like to use the default distinct ID for Mixpanel People as well
 (recommended), call <code>identify:</code> using the current distinct ID:
 <code>[mixpanel identify:mixpanel.distinctId]</code>.

 Not supported on a hierarchical groups project, which identifies a user by company and
 user ID, so it is logged and ignored there. Use <code>identifyWithIdentity:</code> instead.

 @param distinctId string that uniquely identifies the current user
 */
- (void)identify:(NSString *)distinctId;

/*!
 Sets the distinct ID of the current user. With the option of only updating the
 distinct ID value and not the Mixpanel People distinct ID.

 This method is not intended to be used unless you wish to prevent updating the Mixpanel
 People distinct ID value by passing a value of NO to the usePeople param. This can be
 useful if the user wishes to prevent People updates from being sent until the identify
 method is called.

 @param distinctId string that uniquely identifies the current user
 Not supported on a hierarchical groups project, where it is logged and ignored. Use
 <code>identifyWithIdentity:</code> instead.

 @param usePeople bool controls whether or not to set the people distinctId to the event distinctId
 */
- (void)identify:(NSString *)distinctId usePeople:(BOOL)usePeople;

/*!
 Associates all future events and People updates with the given identity.

 On a project that uses hierarchical groups, identify with both a user and a company.
 Mixpanel builds the user's distinct ID from <code>$company_id</code> and <code>$user_id</code>,
 so the company is part of the user's identity: the same user ID in two companies is two users.
 Every later event carries <code>$company_id</code> beside <code>$user_id</code> and
 <code>$device_id</code>, and People updates go to that company's <code>$user_id</code> group
 profile. Both IDs persist across launches until the next identify or <code>reset</code>.

 <pre>
 [mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme"]];
 </pre>

 Calling this with the current user and a different company is an identity change, as switching
 users is. No <code>$identify</code> event is tracked: Mixpanel ties the device to the user from the
 <code>$device_id</code>, <code>$user_id</code> and <code>$company_id</code> on later events. An
 identity without both a user ID and a company ID is logged and ignored. People updates made
 before the first identify are sent now, as this user's profile in this company.

 On any other project Mixpanel ignores <code>$company_id</code>, so an identity that names a
 company is logged and ignored rather than attributed without it. An identity with a nil or
 empty user ID is also logged and ignored.

 On any project an ID that is only whitespace counts as empty, and a user ID starting with
 <code>$device:</code>, which Mixpanel reserves for device IDs, is logged and ignored.

 Mixpanel owns the device ID, which stays the same across identifies so earlier anonymous
 activity follows the user. A <code>deviceId</code> on the identity is ignored, with a warning
 when it differs from <code>anonymousId</code>.

 @param identity the user, and on a hierarchical groups project their company
 */
- (void)identifyWithIdentity:(nullable MixpanelIdentity *)identity NS_SWIFT_NAME(identify(identity:));

/*!
 Add a group to this user's membership for a particular group key.
 The groupKey must be an NSString. The groupID should be a legal MixpanelType value.

 A hierarchical groups project allows one group per group key, so this is dropped with an
 error log there. Use <code>setGroup:groupID:</code> instead.
 
 @param groupKey        the group key
 @param groupID         the group ID
 */
- (void)addGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

/*!
 Remove a group from this user's membership for a particular group key.
 The groupKey must be an NSString. The groupID should be a legal MixpanelType value.

 On a hierarchical groups project this clears the group key when the user belongs to
 groupID, and does nothing otherwise. The <code>$company_id</code> key is set only by
 <code>identifyWithIdentity:</code> there, so removing it is refused with an error log.
 
 @param groupKey        the group key
 @param groupID         the group ID
 */
- (void)removeGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

/*!
 Set the group to which the user belongs.
 The groupKey must be an NSString. The groupID should be an array
 of MixpanelTypes.

 A hierarchical groups project allows one group per group key, so this is dropped with an
 error log there. Use <code>setGroup:groupID:</code> instead, for any key but
 <code>$company_id</code>, which is set only by <code>identifyWithIdentity:</code>.
 
 @param groupKey        the group key
 @param groupIDs        the group IDs
 */
- (void)setGroup:(NSString *)groupKey groupIDs:(NSArray<id<MixpanelType>> *)groupIDs;

/*!
 Convenience method to set a single group ID for the current user.

 On a hierarchical groups project a user belongs to one group per group key, so the group is
 stored as a single value rather than an array, and an array groupID is dropped with an
 error log. The company is set only by <code>identifyWithIdentity:</code>, so a
 <code>$company_id</code> groupKey is refused with an error log there. Before identifying, the
 user profile part of the update is queued until <code>identifyWithIdentity:</code>.
 
 @param groupKey        the group key
 @param groupID         the group ID
 */
- (void)setGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

/*!
 Tracks an event with specific groups.
 
 Similar to track(), the data will also be sent to the specific group
 datasets. Group key/value pairs are upserted into the property map
 before tracking.
 The keys in groups must be NSString objects. values can be any legal
 MixpanelType objects. If the event is being timed, the timer will
 stop and be added as a property.

 A hierarchical groups project allows one group per group key, so a call with an array or
 set group value is dropped with an error log there. Its <code>$company_id</code> is always the
 identified company, as with <code>track:properties:</code>.
 
 @param event               event name
 @param properties          properties dictionary
 @param groups              groups dictionary, which contains key-value pairs
 for this event
 */
- (void)trackWithGroups:(NSString *)event properties:(NSDictionary *)properties groups:(NSDictionary *)groups;

/*!
 Get a MixpanelGroup identifier from groupKey and groupID.
 The groupKey must be an NSString. The groupID should be a legal MixpanelType value.
 
 @param groupKey    the group key
 @param groupID     the group ID
 */
- (MixpanelGroup *)getGroup:(NSString *)groupKey groupID:(id<MixpanelType>)groupID;

/*!
 Returns the identified user's company profile on a hierarchical groups project, as a
 MixpanelGroup to set properties on. This is <code>getGroup:@"$company_id" groupID:companyId</code>
 with the company from the last <code>identifyWithIdentity:</code>.

 <pre>
 [mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme"]];
 [[mixpanel getCompany] set:@{@"tier": @"enterprise"}];
 </pre>

 Only for projects that use hierarchical groups. On any other project, or before a company
 is identified, this returns nil with an error log.

 The company is fixed when this is called, so a group kept across <code>reset</code> or a new
 identify still updates the earlier company.
 */
- (nullable MixpanelGroup *)getCompany;

/*!
 Tracks an event.

 @param event           event name
 */
- (void)track:(NSString *)event;

/*!
 Tracks an event with properties.

 Properties will allow you to segment your events in your Mixpanel reports.
 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects. If the event is being timed, the timer will
 stop and be added as a property.

 On a hierarchical groups project <code>$company_id</code> is part of the user's identity. Once
 a company is identified every event carries it, and a different <code>$company_id</code> in
 properties is replaced with a warning. Before then a <code>$company_id</code> in properties is
 removed with a warning, and the event is still sent.

 @param event           event name
 @param properties      properties dictionary
 */
- (void)track:(NSString *)event properties:(nullable NSDictionary *)properties;

/*!
 Registers super properties, overwriting ones that have already been set.

 Super properties, once registered, are automatically sent as properties for
 all event tracking calls. They save you having to maintain and add a common
 set of properties to your events. Property keys must be <code>NSString</code>
 objects and values must be <code>NSString</code>, <code>NSNumber</code>,
 <code>NSNull</code>, <code>NSArray</code>, <code>NSDictionary</code>,
 <code>NSDate</code> or <code>NSURL</code> objects.

 On a hierarchical groups project <code>$company_id</code> is set only by
 <code>identifyWithIdentity:</code>, so a call that includes it is refused whole with an
 error log.

 @param properties      properties dictionary
 */
- (void)registerSuperProperties:(NSDictionary *)properties;

/*!
 Registers super properties without overwriting ones that have already been
 set.

 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects.

 On a hierarchical groups project <code>$company_id</code> is set only by
 <code>identifyWithIdentity:</code>, so a call that includes it is refused whole with an
 error log.

 @param properties      properties dictionary
 */
- (void)registerSuperPropertiesOnce:(NSDictionary *)properties;

/*!
 Registers super properties without overwriting ones that have already been set
 unless the existing value is equal to defaultValue.

 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects.

 On a hierarchical groups project <code>$company_id</code> is set only by
 <code>identifyWithIdentity:</code>, so a call that includes it is refused whole with an
 error log.

 @param properties      properties dictionary
 @param defaultValue    overwrite existing properties that have this value
 */
- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(nullable id)defaultValue;

/*!
 Removes a previously registered super property.

 As an alternative to clearing all properties, unregistering specific super
 properties prevents them from being recorded on future events. This operation
 does not affect the value of other super properties. Any property name that is
 not registered is ignored.

 Note that after removing a super property, events will show the attribute as
 having the value <code>undefined</code> in Mixpanel until a new value is
 registered.

 On a hierarchical groups project <code>$company_id</code> is set only by
 <code>identifyWithIdentity:</code>, so unregistering it is refused with an error log.

 @param propertyName   array of property name strings to remove
 */
- (void)unregisterSuperProperty:(NSString *)propertyName;

/*!
 Clears all currently set super properties.
 */
- (void)clearSuperProperties;

/*!
 Returns the currently set super properties.
 */
- (NSDictionary *)currentSuperProperties;

/*!
 Starts a timer that will be stopped and added as a property when a
 corresponding event is tracked.

 This method is intended to be used in advance of events that have
 a duration. For example, if a developer were to track an "Image Upload" event
 she might want to also know how long the upload took. Calling this method
 before the upload code would implicitly cause the <code>track</code>
 call to record its duration.

 <pre>
 // begin timing the image upload
 [mixpanel timeEvent:@"Image Upload"];

 // upload the image
 [self uploadImageWithSuccessHandler:^{

    // track the event
    [mixpanel track:@"Image Upload"];
 }];
 </pre>

 @param event   a string, identical to the name of the event that will be tracked

 */
- (void)timeEvent:(NSString *)event;

/*!
 Retrieves the time elapsed for the named event since <code>timeEvent:</code> was called.

 @param event   the name of the event to be tracked that was passed to <code>timeEvent:</code>
 */
- (double)eventElapsedTime:(NSString *)event;

/*!
 Clears the event timer for the named event.
 
 @param event    the name of the event to clear the timer for
 */
- (void)clearTimedEvent:(NSString *)event;

/*!
 Clears all current event timers.
 */
- (void)clearTimedEvents;

/*!
 Clears all stored properties and distinct IDs. Useful if your app's user logs out.
 */
- (void)reset;

/*!
 Uploads queued data to the Mixpanel server.

 By default, queued data is flushed to the Mixpanel servers every minute (the
 default for <code>flushInterval</code>), and on background (since
 <code>flushOnBackground</code> is on by default). You only need to call this
 method manually if you want to force a flush at a particular moment.
 */
- (void)flush;

/*!
 Calls flush, then optionally archives and calls a handler when finished.

 When calling <code>flush</code> manually, it is sometimes important to verify
 that the flush has finished before further action is taken. This is
 especially important when the app is in the background and could be suspended
 at any time if protocol is not followed. 

 @param handler     completion handler to be called after flush completes
 */
- (void)flushWithCompletion:(nullable void (^)(void))handler;

/*!
 Writes current project info, including distinct ID, super properties to disk.

 This state will be recovered when the app is launched again if the Mixpanel
 library is initialized with the same project token. <b>You do not need to call
 this method</b>. The library listens for app state changes and handles
 persisting data as needed. It can be useful in some special circumstances,
 though, for example, if you'd like to track app crashes from main.m.
 */
- (void)archive;

/*!
 The alias method creates an alias which Mixpanel will use to remap one id to another. Multiple aliases can point to the same identifier.

 <pre>
 [mixpanel createAlias:@"New ID"
         forDistinctID:mixpanel.distinctId];
 
 // You can add multiple id aliases to the existing id
 [mixpanel createAlias:@"Newer ID"
         forDistinctID:mixpanel.distinctId];
</pre>

A hierarchical groups project identifies a user by their company and user ID, which an alias
of one distinct ID to another can't express, so this is dropped with an error log there.
Use <code>identifyWithIdentity:</code> instead.

@param alias 		A unique identifier that you want to use as an identifier for this user.
@param distinctID 	The current user identifier.
 */
- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID;

/*!
 Creates a distinct_id alias from alias to original id.

 This method is not intended to be used unless you wish to prevent updating the Mixpanel
 People distinct ID value by passing a value of NO to the usePeople param. This can be
 useful if the user wishes to prevent People updates from being sent until the identify
 method is called.

 Dropped with an error log on a hierarchical groups project. Use
 <code>identifyWithIdentity:</code> instead.

 @param alias         the new distinct_id that should represent original
 @param distinctID     the old distinct_id that alias will be mapped to
 @param usePeople bool controls whether or not to set the people distinctId to the event distinctId
 */
- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID usePeople:(BOOL)usePeople;

/*!
 Returns the Mixpanel library version number as a string, e.g. "3.2.3".
 */
- (NSString *)libVersion;

/*!
 Opt out tracking.

 This method is used to opt out tracking. This causes all events and people request no longer
 to be sent back to the Mixpanel server.
 */
- (void)optOutTracking;

/*!
 Opt in tracking.

 Use this method to opt in an already opted out user from tracking. People updates and track calls will be
 sent to Mixpanel after using this method.

 This method will internally track an opt in event to your project. If you want to identify the opt-in
 event and/or pass properties to the event, See also <code>optInTrackingForDistinctId:</code> and
 <code>optInTrackingForDistinctId:withEventProperties:</code>.
 */
- (void)optInTracking;

/*!
 Opt in tracking.

 Use this method to opt in an already opted out user from tracking. People updates and track calls will be
 sent to Mixpanel after using this method.

 This method will internally track an opt in event to your project. If you want to pass properties to the event, see also
 <code>optInTrackingForDistinctId:withEventProperties:</code>.

 On a hierarchical groups project a distinct ID is logged and ignored and the user stays opted
 out; use <code>optInTrackingWithIdentity:properties:</code> instead. A nil distinct ID opts in
 as <code>optInTracking</code> does.

 @param distinctID     optional string to use as the distinct ID for events. This will call <code>identify:</code>.
 If you use people profiles make sure you manually call <code>identify:</code> after this method.
 */
- (void)optInTrackingForDistinctID:(nullable NSString *)distinctID;

/*!
 Opt in tracking.

 Use this method to opt in an already opted out user from tracking. People updates and track calls will be
 sent to Mixpanel after using this method.

 This method will internally track an opt in event to your project.See also <code>optInTracking</code> or
 <code>optInTrackingForDistinctId:</code>.

 @param distinctID     optional string to use as the distinct ID for events. This will call <code>identify:</code>.
 If you use people profiles make sure you manually call <code>identify:</code> after this method.
 On a hierarchical groups project a distinct ID is logged and ignored and the user stays
 opted out; use <code>optInTrackingWithIdentity:properties:</code> instead. A nil distinct ID
 opts in as <code>optInTracking</code> does.

 @param properties     optional properties dictionary that could be passed to add properties to the opt-in event that is sent to
 Mixpanel.
 */
- (void)optInTrackingForDistinctID:(nullable NSString *)distinctID withEventProperties:(nullable NSDictionary *)properties;

/*!
 Opt in tracking and identify the user.

 Use this method to opt in an already opted out user from tracking. People updates and track calls will be
 sent to Mixpanel after using this method. This method will internally track an opt in event to your project.

 Opting out clears the user's identity, so on a hierarchical groups project use this to opt back in with
 the user's company: the opt-in event and every event after it carry the user and company, which
 <code>optInTrackingForDistinctID:</code> can't express.

 @param identity       optional user, and on a hierarchical groups project their company. This will call
 <code>identifyWithIdentity:</code>. An identity <code>identifyWithIdentity:</code> would refuse is logged, and the
 user stays opted out.
 @param properties     optional properties dictionary that could be passed to add properties to the opt-in event that is sent to
 Mixpanel.
 */
- (void)optInTrackingWithIdentity:(nullable MixpanelIdentity *)identity properties:(nullable NSDictionary *)properties NS_SWIFT_NAME(optInTracking(identity:properties:));

/*!
 Returns YES if the current user has opted out tracking, NO if the current user has opted in tracking.
 */
- (BOOL)hasOptedOutTracking;

/*!
 Returns the Mixpanel library version number as a string, e.g. "3.2.3".
 */
+ (NSString *)libVersion;

@end

/*!
 @protocol

 Delegate protocol for controlling the Mixpanel API's network behavior.

 Creating a delegate for the Mixpanel object is entirely optional. It is only
 necessary when you want full control over when data is uploaded to the server,
 beyond simply calling stop: and start: before and after a particular block of
 your code.
 */

@protocol MixpanelDelegate <NSObject>

@optional
/*!
 Asks the delegate if data should be uploaded to the server.

 Return YES to upload now, NO to defer until later.

 @param mixpanel        Mixpanel API instance
 */
- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel;

@end

NS_ASSUME_NONNULL_END
