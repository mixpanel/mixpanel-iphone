#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

@protocol AloomaDelegate;

/*!
 @class
 Mixpanel API.

 @abstract
 The primary interface for integrating Mixpanel with your app.

 @discussion
 Use the Mixpanel class to set up your project and track events in Mixpanel
 Engagement. It now also includes a <code>people</code> property for accesseing
 the Mixpanel People API.

 <pre>
 // Initialize the API
 Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"YOUR API TOKEN"];

 // Track an event in Mixpanel Engagement
 [mixpanel track:@"Button Clicked"];

 // Set properties on a user in Mixpanel People
 [mixpanel.people identify:@"CURRENT USER DISTINCT ID"];
 [mixpanel.people set:@"Plan" to:@"Premium"];
 </pre>

 For more advanced usage, please see the <a
 href="https://mixpanel.com/docs/integration-libraries/iphone">Mixpanel iPhone
 Library Guide</a>.
 */
@interface Alooma : NSObject

#pragma mark Properties

/*!
 @property

 @abstract
 The distinct ID of the current user.

 @discussion
 A distinct ID is a string that uniquely identifies one of your users.
 Typically, this is the user ID from your database. By default, we'll use a
 hash of the MAC address of the device. To change the current distinct ID,
 use the <code>identify:</code> method.
 */
@property (atomic, readonly, copy) NSString *distinctId;

/*!
 @property

 @abstract
 Current user's name in Mixpanel Streams.
 */
@property (atomic, copy) NSString *nameTag;

/*!
 @property

 @abstract
 The base URL used for Mixpanel API requests.

 @discussion
 Useful if you need to proxy Mixpanel requests. Defaults to
 https://api.mixpanel.com.
 */
@property (atomic, copy) NSString *serverURL;

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
@property (atomic) BOOL showNetworkActivityIndicator;

/*!
 @property

 @abstract
 The a MixpanelDelegate object that can be used to assert fine-grain control
 over Mixpanel network activity.

 @discussion
 Using a delegate is optional. See the documentation for MixpanelDelegate
 below for more information.
 */
@property (atomic, weak) id<AloomaDelegate> delegate; // allows fine grain control over uploading (optional)

#pragma mark Tracking

/*!
 @method

 @abstract
 Initializes and returns a singleton instance of the API.

 @discussion
 If you are only going to send data to a single Mixpanel project from your app,
 as is the common case, then this is the easiest way to use the API. This
 method will set up a singleton instance of the <code>Mixpanel</code> class for
 you using the given project token. When you want to make calls to Mixpanel
 elsewhere in your code, you can use <code>sharedInstance</code>.

 <pre>
 [Mixpanel sharedInstance] track:@"Something Happened"]];
 </pre>

 If you are going to use this singleton approach,
 <code>sharedInstanceWithToken:</code> <b>must be the first call</b> to the
 <code>Mixpanel</code> class, since it performs important initializations to
 the API.

 @param apiToken        your project token
 @param url             your server url
 */
+ (Alooma *)sharedInstanceWithToken:(NSString *)apiToken serverURL:(NSString*)url;

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
 @param url             your server url

 */
+ (Alooma *)sharedInstanceWithToken:(NSString *)apiToken serverURL:(NSString*)url launchOptions:(NSDictionary *)launchOptions;

/*!
 @method

 @abstract
 Returns the previously instantiated singleton instance of the API.

 @discussion
 The API must be initialized with <code>sharedInstanceWithToken:</code> before
 calling this class method.
 */
+ (Alooma *)sharedInstance;

/*!
 @method

 @abstract
 Initializes an instance of the API with the given project token.

 @discussion
 Returns the a new API object. This allows you to create more than one instance
 of the API object, which is convenient if you'd like to send data to more than
 one Mixpanel project from a single app. If you only need to send data to one
 project, consider using <code>sharedInstanceWithToken:</code>.

 @param apiToken        your project token
 @param launchOptions   optional app delegate launchOptions
 @param flushInterval   interval to run background flushing
 @param url             your server url
 */
- (instancetype)initWithToken:(NSString *)apiToken serverURL:(NSString*)url launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval;

/*!
 @method

 @abstract
 Initializes an instance of the API with the given project token.

 @discussion
 Supports for the old initWithToken method format but really just passes
 launchOptions to the above method as nil.

 @param apiToken        your project token
 @param flushInterval   interval to run background flushing
 @param url             your server url
 */
- (instancetype)initWithToken:(NSString *)apiToken serverURL:(NSString*)url andFlushInterval:(NSUInteger)flushInterval;

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
 Arguments will allow you to segment your events in your Mixpanel reports.
 Argument keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects. If the event is being timed, the timer will
 stop and be added as a property.
 
 @param properties           arguments dictionary
 
 */
- (void)trackCustomEvent:(NSDictionary *)customEvent;

/*!
 @method

 @abstract
 Tracks an event with properties.

 @discussion
 Arguments will allow you to segment your events in your Mixpanel reports.
 Argument keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects. If the event is being timed, the timer will
 stop and be added as a property.

 @param event           event name
 @param properties      properties dictionary
 */
- (void)track:(NSString *)event customEvent:(NSDictionary *)customEvent;

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
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

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
- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(id)defaultValue;

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
 default for <code>flushInvterval</code>), and on background (since
 <code>flushOnBackground</code> is on by default). You only need to call this
 method manually if you want to force a flush at a particular moment.
 */
- (void)flush;

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

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID;

- (NSString *)libVersion;

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
@protocol AloomaDelegate <NSObject>
@optional

/*!
 @method

 @abstract
 Asks the delegate if data should be uploaded to the server.

 @discussion
 Return YES to upload now, NO to defer until later.

 @param mixpanel        Mixpanel API instance
 */
- (BOOL)aloomaWillFlush:(Alooma *)mixpanel;

@end
