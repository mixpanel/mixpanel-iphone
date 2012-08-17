//
//  MixpanelAPI.h
//  MPLib
//
//

/*!
 @header     MixpanelLib
 @abstract   iOS Mixpanel Library
 @discussion This library lets you use Mixpanel analytics in iOS applications.
*/

#import <Foundation/Foundation.h>
@class MixpanelAPI;
/*!
 @protocol   MixpanelDelegate
 @abstract	 A delegate for the MixpanelAPI
 @discussion A delegate for the MixpanelAPI
 */
@protocol MixpanelDelegate <NSObject>
@optional

/*!
 @method     mixpanel:willUploadEvents   
 @abstract   Asks the delegate if the events should be uploaded.
 @discussion Return YES to upload events, NO to not upload events.
 @param      mixpanel The Mixpanel API
 @param      events The events that will be uploaded.
 */
- (BOOL)mixpanel:(MixpanelAPI *) mixpanel willUploadEvents:(NSArray *) events;
/*!
 @method     mixpanel:didUploadEvents   
 @abstract   Notifies the delegate that the events have been uploaded
 @discussion Notifies the delegate that the events have been uploaded
 @param      mixpanel The Mixpanel API
 @param      events The events that will be uploaded.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didUploadEvents:(NSArray *) events;
/*!
 @method     mixpanel:didFailToUploadEvents:withError   
 @abstract   Notifies the delegate that there was an error while uploading events.
 @discussion Notifies the delegate that there was an error while uploading events.
 @param      mixpanel The Mixpanel API
 @param      events The events that will be uploaded.
 @param      error the error that ocurred.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didFailToUploadEvents:(NSArray *) events withError:(NSError *) error;

/*!
 @method     mixpanel:willUploadPeople
 @abstract   Asks the delegate if the people should be uploaded.
 @discussion Return YES to upload people, NO to not upload people.
 @param      mixpanel The Mixpanel API
 @param      people The people that will be uploaded.
 */
- (BOOL)mixpanel:(MixpanelAPI *) mixpanel willUploadPeople:(NSArray *) people;
/*!
 @method     mixpanel:didUploadPeople   
 @abstract   Notifies the delegate that the people have been uploaded
 @discussion Notifies the delegate that the people have been uploaded
 @param      mixpanel The Mixpanel API
 @param      people The people that were uploaded.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didUploadPeople:(NSArray *) people;
/*!
 @method     mixpanel:didFailToUploadPeople:withError   
 @abstract   Notifies the delegate that there was an error while uploading people.
 @discussion Notifies the delegate that there was an error while uploading people.
 @param      mixpanel The Mixpanel API
 @param      people The people that were to be uploaded.
 @param      error The error that ocurred.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didFailToUploadPeople:(NSArray *) people withError:(NSError *) error;

@end
/*!
 @const		 kMPUploadInterval
 @abstract   The default number of seconds between data uploads to the Mixpanel server
 @discussion The default number of seconds between data uploads to the Mixpanel server
*/
static const NSUInteger kMPUploadInterval = 30;
/*!
 @class		 MixpanelAPI
 @abstract	 Main entry point for the Mixpanel API.
 @discussion With MixpanelAPI you can log events and people data.
*/
@interface MixpanelAPI : NSObject {
	NSString *apiToken;
	NSMutableArray *eventQueue;
    NSMutableArray *peopleQueue;
	NSMutableDictionary *superProperties;
	NSTimer *timer;
	NSArray *eventsToSend;
    NSArray *peopleToSend;
	NSMutableData *responseData;
    NSMutableData *peopleResponseData;
	NSURLConnection *connection;
    NSURLConnection *people_connection;
    id<MixpanelDelegate> delegate;
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	UIBackgroundTaskIdentifier taskId;
	#endif
	NSString *defaultUserId;
	NSUInteger uploadInterval;
	BOOL testMode;
    BOOL sendDeviceModel;
}
/*! 
 @property   uploadInterval
 @abstract   The upload interval in seconds.
 @discussion Changes the interval value. Changing this values resets the update timer with the new interval.
*/
@property(nonatomic, assign) NSUInteger uploadInterval;

/*! 
 @property   flushOnBackground
 @abstract   Flag to flush data when the app goes into the background.
 @discussion Changes the flushing behavior of the library. If set to NO, the The library will not flush the data points when going into the background. Defaults to YES.
 */
@property(nonatomic, assign) BOOL flushOnBackground;

/*! 
 @property   nameTag
 @abstract   The name tag of the current user.
 @discussion The name tag is a human readable string that identifies the user.
 */
@property(nonatomic, retain) NSString *nameTag;

/*! 
 @property   testMode
 @abstract   Whether test mode is on
 @discussion Changing this value enables/disables test mode for future flushes.
*/
@property(nonatomic) BOOL testMode;


/*! 
 @property   serverURL
 @abstract   The Mixpanel API endpoint, no trailing slash
 @discussion Allows setting a custom API URL. Defaults to https://api.mixpanel.com
 */
@property(retain) NSString *serverURL;


/*! 
 @property   delegate
 @abstract   The Mixpanel API delegate 
 @discussion Allows finer grain control over uploading events.
 */
@property(assign) id<MixpanelDelegate> delegate;

/*! 
 @property   sendDeviceModel
 @abstract   Tells the Mixpane API to send the device model as a super property.
 @discussion Tells the Mixpane API to send the device model as a super property.
 */
@property(nonatomic, assign) BOOL sendDeviceModel;
/*!
 @method     sharedAPIWithToken:
 @abstract   Initializes the API with your API Token. Returns the shared API object.
 @discussion Initializes the MixpanelAPI object with your authentication token. 
             This must be the first message sent before logging any events since it performs important
             initializations to the API.
 @param      apiToken Your Mixpanel API token.
*/
+ (id)sharedAPIWithToken:(NSString*)apiToken;

/*!
 @method     sharedAPI   
 @abstract   Returns the shared API object.
 @discussion Returns the Singleton instance of the MixpanelAPI class. 
             The API must be initialized with <code>sharedAPIWithToken:</code> before calling this class method.
*/
+ (id)sharedAPI;

/*!
 @method     initWithToken:
 @abstract   Initializes the API with your API Token. Returns the a new API object.
 @discussion Initializes an instance of the MixpanelAPI object with your authentication token. 
             This must be the first message sent before logging any events since it performs important
             initializations to the API.
 @param      apiToken Your Mixpanel API token.
 */
- (id)initWithToken:(NSString*)apiToken;


/*!
 @method     stop
 @abstract   Stops the background execution of the MixPanel API instance. 
 @discussion Removes this instance as an observer to application lifecycle events and stops the background timers. 
             Calling this method is required before disposing of this instance.
 */
- (void)stop;
/*!
 @method     start
 @abstract   Restarts the background execution of the MixPanel API instance.
 @discussion Adds this instance as an observer to application lifecycle events and starts the background timers.
             This method is called automatically on initializating. You should only call it manually if you called stop previously. 
 */
- (void)start;

/*!
 @method     setSendDeviceModel:
 @abstract   Sets whether to send current device info
 @discussion If passed YES, all events tracked will include the mp_device_type, $os_version, $app_version 
             properties and people set will include $device_model, $os_version, $app_version properties
 @param      sendDeviceModel a BOOL that indicates whether to send device model or not
 */
-(void)setSendDeviceModel:(BOOL)sendDeviceModel;


/*!
 @method	 registerSuperProperties:
 @abstract	 Registers a set of super properties for all event types.
 @discussion Registers a set of super properties, overwriting property values if they already exist. 
             Super properties are added to all the data points. 				
             The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.	
 @param		 properties a NSDictionary with the super properties to register.
             properties that will be registered with both events and funnels.
 
 */
- (void)registerSuperProperties:(NSDictionary*) properties;

/*!
 @method     registerSuperPropertiesOnce:
 @abstract   Registers a set of super properties unless the property already exists.
 @discussion Registers a set of super properties, without overwriting existing key\value pairs. 
             Super properties are added to all the data points.
             The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
 @param		 properties a NSDictionary with the super properties to register.
             properties that will be registered with both events and funnels.
 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties;

/*!
 @method     registerSuperPropertiesOnce:defaultValue:
 @abstract   Registers a set of super properties without overwriting existing values unless the existing value is equal to defaultValue.
 @discussion Registers a set of super properties, without overwriting existing key\value pairs. If the value of an existing property is equal to defaultValue, 
             then this method will update the value of that property.  Super properties are added to all the data points.
             The API must be initialized with <code>sharedAPIWithToken:</code> or <code>initWithToken:</code> before calling this method.
 @param		 properties a NSDictionary with the super properties to register.
 @param      defaultValue If an existing property is equal to defaultValue, the value of said property gets updated.
 
 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties defaultValue:(id) defaultValue;

/*!
 @method     identifyUser:
 @abstract   Identifies a user.
 @discussion Identifies a user throughout an application run. 
             By default a one-way hash of the MAC address is used as an identifier.
             The API must be initialized with <code>sharedAPIWithToken:</code> or <code>initWithToken:</code>
             before calling this method.
 @param		 identity A string to use as a user identity.
 */
- (void)identifyUser:(NSString*) identity;

/*!
 @method	 track:
 @abstract   Tracks an event.
 @discussion Tracks an event. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeEvent</code> get attached to events.
             If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
             The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
 @param		 event The event to track.
 */
- (void)track:(NSString*) event;

/*!
 @method     track:properties:
 @abstract   Tracks an event with properties.
 @discussion Tracks an event. The properties of this event are a union of the super properties of type Super properties of type 
             <code>kMPLibEventTypeAll</code>, <code>kMPLibEventTypeEvent</code> and the <code>properties</code> parameter. 
             The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
 @param		 event The event to track. If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
 @param		 properties The properties for this event. The keys must be NSString objects and the values should be NSString or NSNumber objects.
 */
- (void)track:(NSString*) event properties:(NSDictionary*) properties;

/*!
 @method     setUserProperties:
 @abstract   Set properties on the user.
 @discussion The properties will be set on the current user. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      properties The properties to set. The keys must be NSString objects and the values should be
             NSString, NSNumber, NSArray, NSDate, or NSNull objects. You can over-ride the default $token and $distinct_id
             on specific requests by creating entries in this dictionary with the corresponding keys.
 */
- (void)setUserProperties:(NSDictionary*)properties;

/*!
 @method     setUserProperty:forKey:
 @abstract   Set a single property on the user.
 @discussion The property will be set on the current user. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      property The value of the property to set. Should be NSString, NSNumber, NSArray, NSDate, or NSNull.
 @param      key The key of the property to set.
 */
- (void)setUserProperty:(id)property forKey:(NSString*)key;

/*!
 @method     incrementUserProperties:
 @abstract   Increment the given numeric properties by the given values.
 @discussion Increment the given numeric properties by the given values. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      properties The properties to increment. The keys must be NSString objects corresponding to the property
             keys to increment, and the values must be NSNumbers corresponding to the amount to increment by.
             You can over-ride the default $token and $distinct_id on specific requests by creating entries in this 
             dictionary with the corresponding keys.
 */
- (void)incrementUserProperties:(NSDictionary*)properties;

/*!
 @method     incrementPropertyWithKey:
 @abstract   Increment the given numeric property by 1.
 @discussion A convienience method for incrementing a single numeric property by 1. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      key The key of the property to increment.
 */
- (void)incrementUserPropertyWithKey:(NSString*)key;

/*!
 @method     incrementPropertyWithKey:byNumber:
 @abstract   Increment the given numeric property by the given NSNumber.
 @discussion Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      key The key of the property to increment.
 @param      amount The amount to increment by.
 */
- (void)incrementUserPropertyWithKey:(NSString*)key byNumber:(NSNumber*)amount;

/*!
 @method     incrementUserPropertyWithKey:byInt:
 @abstract   Increment the given numeric property by the given int.
 @discussion Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      key The key of the property to increment.
 @param      amount The amount to increment by.
 */
- (void)incrementUserPropertyWithKey:(NSString*)key byInt:(int)amount;

/*!
 @method     append:toUserPropertyWithKey:
 @abstract   Append an item to a list property.
 @discussion Append an item to a list property. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 @param      item The item to append. Should be NSString, NSNumber, NSArray, NSDate, or NSNull object
 @param      key The key of the list property to append to.
 */
- (void)append:(id)item toUserPropertyWithKey:(NSString*)key;

/*!
 @method     deleteUser:
 @abstract   Deletes the record for the user with the given $distinct_id
 @discussion Deletes the record for the user with the given $distinct_id. The API must be initialized by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> before calling this method.
 @param      distinctId The $distinct_id of the user to delete.
 */
- (void)deleteUser:(NSString*)distinctId;

/*!
 @method     deleteCurrentUser
 @abstract   Deletes the record for the current user.
 @discussion Deletes the record for the current user. Note that if the user's $distinct_id is not set
             an exception will be raised. The $distinct_id is set automatically by calling <code>initWithToken:</code>
             or <code>sharedAPIWithToken:</code> and can be manually set by calling <code>identifyUser:</code>.
 */
- (void)deleteCurrentUser;

/*!
 @method     flush
 @abstract   Uploads event & people datapoints to the Mixpanel Server.
 @discussion Uploads event & people datapoints to the Mixpanel Server.
 */
- (void)flush;

/*!
 @method     flushEvents
 @abstract   Uploads event datapoints to the Mixpanel Server.
 @discussion Uploads event datapoints to the Mixpanel Server.
 */
- (void)flushEvents;

/*!
 @method     flushPeople
 @abstract   Uploads people datapoints to the Mixpanel Server.
 @discussion Uploads people datapoints to the Mixpanel Server.
 */
- (void)flushPeople;

/*!
 @method     registerDeviceToken:
 @abstract   Register the given device to receive push notifications
 @discussion Register the given device to receive push notifications from Mixpanel
 */
- (void)registerDeviceToken:(NSData*)deviceToken;

/*!
 @method     handlePush:
 @abstract   Display an alert view with the push message
 @discussion This is a convenience method that displays an alert view when your app is in
             the foreground and receives a remote notification. You can call this method from
             your app delegate's application:didReceiveRemoteNotification: method.
 */
- (void)handlePush:(NSDictionary*)userInfo;

@end
