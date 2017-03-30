#import <Foundation/Foundation.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MixpanelPeople.h"

#define MIXPANEL_FLUSH_IMMEDIATELY (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_WATCHOS))
#define MIXPANEL_NO_REACHABILITY_SUPPORT (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_TVOS) || defined(MIXPANEL_WATCHOS) || defined(MIXPANEL_MACOS))
#define MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_TVOS) || defined(MIXPANEL_WATCHOS) || defined(MIXPANEL_MACOS))
#define MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_TVOS) || defined(MIXPANEL_WATCHOS) || defined(MIXPANEL_MACOS))
#define MIXPANEL_NO_APP_LIFECYCLE_SUPPORT (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_WATCHOS))
#define MIXPANEL_NO_UIAPPLICATION_ACCESS (defined(MIXPANEL_APP_EXTENSION) || defined(MIXPANEL_WATCHOS) || defined(MIXPANEL_MACOS))

@class    MixpanelPeople;
@protocol MixpanelDelegate;

NS_ASSUME_NONNULL_BEGIN

/*!
 @class
 Mixpanel API.

 @abstract
 The primary interface for integrating Mixpanel with your app.

 @discussion
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

/*!
 @property

 @abstract
 Accessor to the Mixpanel People API object.

 @discussion
 See the documentation for MixpanelDelegate below for more information.
 */
@property (atomic, readonly, strong) MixpanelPeople *people;

/*!
 @property

 @abstract
 The distinct ID of the current user.

 @discussion
 A distinct ID is a string that uniquely identifies one of your users. By default, 
 we'll use the device's advertisingIdentifier UUIDString, if that is not available
 we'll use the device's identifierForVendor UUIDString, and finally if that
 is not available we will generate a new random UUIDString. To change the
 current distinct ID, use the <code>identify:</code> method.
 */
@property (atomic, readonly, copy) NSString *distinctId;

/*!
 @property
 
 @abstract
 The alias of the current user.
 
 @discussion
 An alias is another string that uniquely identifies one of your users. Typically, 
 this is the user ID from your database. By using an alias you can link pre- and
 post-sign up activity as well as cross-platform activity under one distinct ID.
 To set the alias use the <code>createAlias:forDistinctID:</code> method.
 */
@property (atomic, readonly, copy) NSString *alias;

/*!
 @property

 @abstract
 The base URL used for Mixpanel API requests.

 @discussion
 Useful if you need to proxy Mixpanel requests. Defaults to
 https://api.mixpanel.com.
 */
@property (nonatomic, copy) NSString *serverURL;

/*!
 @property

 @abstract
 Flush timer's interval.

 @discussion
 Setting a flush interval of 0 will turn off the flush timer.
 */
@property (atomic) NSUInteger flushInterval;

/*!
 @property

 @abstract
 Control whether the library should flush data to Mixpanel when the app
 enters the background.

 @discussion
 Defaults to YES. Only affects apps targeted at iOS 4.0, when background
 task support was introduced, and later.
 */
@property (atomic) BOOL flushOnBackground;

/*!
 @property

 @abstract
 Controls whether to show spinning network activity indicator when flushing
 data to the Mixpanel servers.

 @discussion
 Defaults to YES.
 */
@property (atomic) BOOL shouldManageNetworkActivityIndicator;

/*!
 @property

 @abstract
 Controls whether to automatically check for notifications for the
 currently identified user when the application becomes active.

 @discussion
 Defaults to YES. Will fire a network request on
 <code>applicationDidBecomeActive</code> to retrieve a list of valid notifications
 for the currently identified user.
 */
@property (atomic) BOOL checkForNotificationsOnActive;

/*!
 @property

 @abstract
 Controls whether to automatically check for A/B test variants for the
 currently identified user when the application becomes active.

 @discussion
 Defaults to YES. Will fire a network request on
 <code>applicationDidBecomeActive</code> to retrieve a list of valid variants
 for the currently identified user.
 */
@property (atomic) BOOL checkForVariantsOnActive;

/*!
 @property

 @abstract
 Controls whether to automatically check for and show in-app notifications
 for the currently identified user when the application becomes active.

 @discussion
 Defaults to YES.
 */
@property (atomic) BOOL showNotificationOnActive;

/*!
 @property
 
 @abstract
 Controls whether to automatically send the client IP Address as part of 
 event tracking. With an IP address, geo-location is possible down to neighborhoods
 within a city, although the Mixpanel Dashboard will just show you city level location
 specificity. For privacy reasons, you may be in a situation where you need to forego
 effectively having access to such granular location information via the IP Address.
 
 @discussion
 Defaults to YES.
 */
@property (atomic) BOOL useIPAddressForGeoLocation;

/*!
 @property
 
 @abstract
 Controls whether to enable the visual test designer for A/B testing and codeless on mixpanel.com. 
 You will be unable to edit A/B tests and codeless events with this disabled, however *previously*
 created A/B tests and codeless events will still be delivered.
 
 @discussion
 Defaults to YES.
 */
@property (atomic) BOOL enableVisualABTestAndCodeless;

/*!
 @property
 
 @abstract
 Controls whether to enable the run time debug logging at all levels. Note that the
 Mixpanel SDK uses Apple System Logging to forward log messages to `STDERR`, this also
 means that mixpanel logs are segmented by log level. Settings this to `YES` will enable 
 Mixpanel logging at the following levels:
 
   * Error - Something has failed 
   * Warning - Something is amiss and might fail if not corrected
   * Info - The lowest priority that is normally logged, purely informational in nature
   * Debug - Information useful only to developers, and normally not logged.
 
 
 @discussion
 Defaults to NO.
 */
@property (atomic) BOOL enableLogging;

/*!
 @property

 @abstract
 Determines the time, in seconds, that a mini notification will remain on
 the screen before automatically hiding itself.

 @discussion
 Defaults to 6.0.
 */
@property (atomic) CGFloat miniNotificationPresentationTime;

/*!
 @property

 @abstract
 The a MixpanelDelegate object that can be used to assert fine-grain control
 over Mixpanel network activity.

 @discussion
 Using a delegate is optional. See the documentation for MixpanelDelegate
 below for more information.
 */
@property (atomic, weak) id<MixpanelDelegate> delegate; // allows fine grain control over uploading (optional)

#pragma mark Tracking

/*!
 @method

 @abstract
 Returns (and creates, if needed) a singleton instance of the API.

 @discussion
 This method will return a singleton instance of the <code>Mixpanel</code> class for
 you using the given project token. If an instance does not exist, this method will create
 one using <code>initWithToken:launchOptions:andFlushInterval:</code>. If you only have one
 instance in your project, you can use <code>sharedInstance</code> to retrieve it.

 <pre>
 [Mixpanel sharedInstance] track:@"Something Happened"]];
 </pre>

 If you are going to use this singleton approach,
 <code>sharedInstanceWithToken:</code> <b>must be the first call</b> to the
 <code>Mixpanel</code> class, since it performs important initializations to
 the API.

 @param apiToken        your project token
 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken;

/*!
 @method

 @abstract
 Initializes a singleton instance of the API, uses it to track launchOptions information,
 and then returns it.

 @discussion
 This is the preferred method for creating a sharedInstance with a mixpanel
 like above. With the launchOptions parameter, Mixpanel can track referral
 information created by push notifications.

 @param apiToken        your project token
 @param launchOptions   your application delegate's launchOptions

 */
+ (Mixpanel *)sharedInstanceWithToken:(NSString *)apiToken launchOptions:(nullable NSDictionary *)launchOptions;

/*!
 @method

 @abstract
 Returns a previously instantiated singleton instance of the API.

 @discussion
 The API must be initialized with <code>sharedInstanceWithToken:</code> or
 <code>initWithToken:launchOptions:andFlushInterval</code> before calling this class method.
 This method will return <code>nil</code> if there are no instances created. If there is more than 
 one instace, it will return the first one that was created by using <code>sharedInstanceWithToken:</code> 
 or <code>initWithToken:launchOptions:andFlushInterval:</code>.
 */
+ (nullable Mixpanel *)sharedInstance;

/*!
 @method

 @abstract
 Initializes an instance of the API with the given project token.

 @discussion
 Creates and initializes a new API object. See also <code>sharedInstanceWithToken:</code>.

 @param apiToken        your project token
 @param launchOptions   optional app delegate launchOptions
 @param flushInterval   interval to run background flushing
 */
- (instancetype)initWithToken:(NSString *)apiToken launchOptions:(nullable NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval;

/*!
 @method

 @abstract
 Initializes an instance of the API with the given project token.

 @discussion
 Supports for the old initWithToken method format but really just passes
 launchOptions to the above method as nil.

 @param apiToken        your project token
 @param flushInterval   interval to run background flushing
 */
- (instancetype)initWithToken:(NSString *)apiToken andFlushInterval:(NSUInteger)flushInterval;

/*!
 @property

 @abstract
 Sets the distinct ID of the current user.

 @discussion
 As of version 2.3.1, Mixpanel will choose a default distinct ID based on
 whether you are using the AdSupport.framework or not.

 If you are not using the AdSupport Framework (iAds), then we use the
 <code>[UIDevice currentDevice].identifierForVendor</code> (IFV) string as the
 default distinct ID.  This ID will identify a user across all apps by the same
 vendor, but cannot be used to link the same user across apps from different
 vendors.

 If you are showing iAds in your application, you are allowed use the iOS ID
 for Advertising (IFA) to identify users. If you have this framework in your
 app, Mixpanel will use the IFA as the default distinct ID. If you have
 AdSupport installed but still don't want to use the IFA, you can define the
 <code>MIXPANEL_NO_IFA</code> preprocessor flag in your build settings, and
 Mixpanel will use the IFV as the default distinct ID.

 If we are unable to get an IFA or IFV, we will fall back to generating a
 random persistent UUID.

 For tracking events, you do not need to call <code>identify:</code> if you
 want to use the default.  However, <b>Mixpanel People always requires an
 explicit call to <code>identify:</code></b>. If calls are made to
 <code>set:</code>, <code>increment</code> or other <code>MixpanelPeople</code>
 methods prior to calling <code>identify:</code>, then they are queued up and
 flushed once <code>identify:</code> is called.

 If you'd like to use the default distinct ID for Mixpanel People as well
 (recommended), call <code>identify:</code> using the current distinct ID:
 <code>[mixpanel identify:mixpanel.distinctId]</code>.

 @param distinctId string that uniquely identifies the current user
 */
- (void)identify:(NSString *)distinctId;

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


/*!
 @method

 @abstract
 Track a push notification using its payload sent from Mixpanel.

 @discussion
 To simplify user interaction tracking and a/b testing, Mixpanel
 automatically sends IDs for the relevant notification and a/b variants
 of each push. This method parses the standard payload and queues a
 track call using this information.

 @param userInfo         remote notification payload dictionary
 */
- (void)trackPushNotification:(NSDictionary *)userInfo;


/*!
 @method

 @abstract
 Registers super properties, overwriting ones that have already been set.

 @discussion
 Super properties, once registered, are automatically sent as properties for
 all event tracking calls. They save you having to maintain and add a common
 set of properties to your events. Property keys must be <code>NSString</code>
 objects and values must be <code>NSString</code>, <code>NSNumber</code>,
 <code>NSNull</code>, <code>NSArray</code>, <code>NSDictionary</code>,
 <code>NSDate</code> or <code>NSURL</code> objects.

 @param properties      properties dictionary
 */
- (void)registerSuperProperties:(NSDictionary *)properties;

/*!
 @method

 @abstract
 Registers super properties without overwriting ones that have already been
 set.

 @discussion
 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects.

 @param properties      properties dictionary
 */
- (void)registerSuperPropertiesOnce:(NSDictionary *)properties;

/*!
 @method

 @abstract
 Registers super properties without overwriting ones that have already been set
 unless the existing value is equal to defaultValue.

 @discussion
 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects.

 @param properties      properties dictionary
 @param defaultValue    overwrite existing properties that have this value
 */
- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(nullable id)defaultValue;

/*!
 @method

 @abstract
 Removes a previously registered super property.

 @discussion
 As an alternative to clearing all properties, unregistering specific super
 properties prevents them from being recorded on future events. This operation
 does not affect the value of other super properties. Any property name that is
 not registered is ignored.

 Note that after removing a super property, events will show the attribute as
 having the value <code>undefined</code> in Mixpanel until a new value is
 registered.

 @param propertyName   array of property name strings to remove
 */
- (void)unregisterSuperProperty:(NSString *)propertyName;

/*!
 @method

 @abstract
 Clears all currently set super properties.
 */
- (void)clearSuperProperties;

/*!
 @method

 @abstract
 Returns the currently set super properties.
 */
- (NSDictionary *)currentSuperProperties;

/*!
 @method

 @abstract
 Starts a timer that will be stopped and added as a property when a
 corresponding event is tracked.

 @discussion
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
 @method

 @abstract
 Clears all current event timers.
 */
- (void)clearTimedEvents;

/*!
 @method

 @abstract
 Clears all stored properties and distinct IDs. Useful if your app's user logs out.
 */
- (void)reset;

/*!
 @method

 @abstract
 Uploads queued data to the Mixpanel server.

 @discussion
 By default, queued data is flushed to the Mixpanel servers every minute (the
 default for <code>flushInterval</code>), and on background (since
 <code>flushOnBackground</code> is on by default). You only need to call this
 method manually if you want to force a flush at a particular moment.
 */
- (void)flush;

/*!
 @method
 
 @abstract
 Calls flush, then optionally archives and calls a handler when finished.
 
 @discussion
 When calling <code>flush</code> manually, it is sometimes important to verify
 that the flush has finished before further action is taken. This is
 especially important when the app is in the background and could be suspended
 at any time if protocol is not followed. Delegate methods like
 <code>application:didReceiveRemoteNotification:fetchCompletionHandler:</code>
 are called when an app is brought to the background and require a handler to
 be called when it finishes.
 */
- (void)flushWithCompletion:(nullable void (^)())handler;

/*!
 @method

 @abstract
 Writes current project info, including distinct ID, super properties and pending event
 and People record queues to disk.

 @discussion
 This state will be recovered when the app is launched again if the Mixpanel
 library is initialized with the same project token. <b>You do not need to call
 this method</b>. The library listens for app state changes and handles
 persisting data as needed. It can be useful in some special circumstances,
 though, for example, if you'd like to track app crashes from main.m.
 */
- (void)archive;

/*!
 @method

 @abstract
 Creates a distinct_id alias from alias to original id.

 @discussion
 This method is used to map an identifier called an alias to the existing Mixpanel
 distinct id. This causes all events and people requests sent with the alias to be
 mapped back to the original distinct id. The recommended usage pattern is to call
 both createAlias: and identify: when the user signs up, and only identify: (with
 their new user ID) when they log in. This will keep your signup funnels working
 correctly.

 <pre>
 // This makes the current ID (an auto-generated GUID)
 // and 'Alias' interchangeable distinct ids.
 [mixpanel createAlias:@"Alias"
    forDistinctID:mixpanel.distinctId];

 // You must call identify if you haven't already
 // (e.g., when your app launches).
 [mixpanel identify:mixpanel.distinctId];
</pre>

@param alias 		the new distinct_id that should represent original
@param distinctID 	the old distinct_id that alias will be mapped to
 */
- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID;

- (NSString *)libVersion;
+ (NSString *)libVersion;


#if !MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT
#pragma mark - Mixpanel Notifications

/*!
 @method

 @abstract
 Shows the notification of the given id.

 @discussion
 You do not need to call this method on the main thread.
 */
- (void)showNotificationWithID:(NSUInteger)ID;


/*!
 @method

 @abstract
 Shows a notification with the given type if one is available.

 @discussion
 You do not need to call this method on the main thread.

 @param type The type of notification to show, either @"mini", or @"takeover"
 */
- (void)showNotificationWithType:(NSString *)type;

/*!
 @method

 @abstract
 Shows a notification if one is available.

 @discussion
 You do not need to call this method on the main thread.
 */
- (void)showNotification;

#pragma mark - Mixpanel A/B Testing

/*!
 @method

 @abstract
 Join any experiments (A/B tests) that are available for the current user.

 @discussion
 Mixpanel will check for A/B tests automatically when your app enters
 the foreground. Call this method if you would like to to check for,
 and join, any experiments are newly available for the current user.

 You do not need to call this method on the main thread.
 */
- (void)joinExperiments;

/*!
 @method

 @abstract
 Join any experiments (A/B tests) that are available for the current user.

 @discussion
 Same as joinExperiments but will fire the given callback after all experiments
 have been loaded and applied.
 */
- (void)joinExperimentsWithCallback:(nullable void (^)())experimentsLoadedCallback;

#endif // MIXPANEL_NO_NOTIFICATION_AB_TEST_SUPPORT

#pragma mark - Deprecated
/*!
 @property
 
 @abstract
 Current user's name in Mixpanel Streams.
 */
@property (nullable, atomic, copy) NSString *nameTag __deprecated; // Deprecated in v3.0.1

@end

/*!
 @protocol

 @abstract
 Delegate protocol for controlling the Mixpanel API's network behavior.

 @discussion
 Creating a delegate for the Mixpanel object is entirely optional. It is only
 necessary when you want full control over when data is uploaded to the server,
 beyond simply calling stop: and start: before and after a particular block of
 your code.
 */

@protocol MixpanelDelegate <NSObject>

@optional
/*!
 @method

 @abstract
 Asks the delegate if data should be uploaded to the server.

 @discussion
 Return YES to upload now, NO to defer until later.

 @param mixpanel        Mixpanel API instance
 */
- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel;

@end

NS_ASSUME_NONNULL_END
