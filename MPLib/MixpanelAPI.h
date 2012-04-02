//
//  MixpanelLib.h
//  MPLib
//
//

/*!
    @header MixpanelLib
    @abstract   iOS Mixpanel Library
    @discussion This library lets you use Mixpanel analytics in iOS applications.
*/

#import <Foundation/Foundation.h>
@class MixpanelAPI;
/*!
 @protocol	MixpanelDelegate
 @abstract	A delegate for the MixpanelAPI
 @discussion A delegate for the MixpanelAPI
 */
@protocol MixpanelDelegate <NSObject>
@optional

/*!
 @method     mixpanel:willUploadEvents   
 @abstract   Asks the delegate if the events should be uploaded.
 @discussion Returns YES to upload events, NO to not upload events.
 @param mixpanel The Mixpanel API
 @param events The events that will be uploaded.
 */
- (BOOL)mixpanel:(MixpanelAPI *) mixpanel willUploadEvents:(NSArray *) events;
/*!
 @method     mixpanel:didUploadEvents   
 @abstract   Notifies the delegate that the events have been uploaded
 @discussion Notifies the delegate that the events have been uploaded
 @param mixpanel The Mixpanel API
 @param events The events that will be uploaded.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didUploadEvents:(NSArray *) events;

/*!
 @method     mixpanel:didFailToUploadEvents:withError   
 @abstract   Notifies the delegate that there was an error while uploading events.
 @discussion Notifies the delegate that there was an error while uploading events.
 @param mixpanel The Mixpanel API
 @param events The events that will be uploaded.
 @param error the error that ocurred.
 */
- (void)mixpanel:(MixpanelAPI *) mixpanel didFailToUploadEvents:(NSArray *) events withError:(NSError *) error;
@end
/*!
    @const		kMPUploadInterval
    @abstract   The default number of seconds between data uploads to the Mixpanel server
    @discussion The default number of seconds between data uploads to the Mixpanel server
*/
static const NSUInteger kMPUploadInterval = 30;
/*!
    @class		MixpanelAPI
    @abstract	Main entry point for the Mixpanel API.
    @discussion With MixpanelAPI you can log events and analyze funnels using the Mixpanel dashboard.
*/
@interface MixpanelAPI : NSObject {
	NSString *apiToken;
	NSMutableArray *eventQueue;
	NSMutableDictionary *superProperties;
	NSTimer *timer;
	NSArray *eventsToSend;
	NSMutableData *responseData;
	NSURLConnection *connection;
    id<MixpanelDelegate> delegate;
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	UIBackgroundTaskIdentifier taskId;
	#endif
	NSString *defaultUserId;
	NSUInteger uploadInterval;
	BOOL testMode;
    BOOL sendDeviceModel;
}
/*! @property uploadInterval
	@abstract The upload interval in seconds.
	@discussion Changes the interval value. Changing this values resets the update timer with the new interval.
*/
@property(nonatomic, assign) NSUInteger uploadInterval;

/*! @property flushOnBackground
 @abstract Flag to flush data when the app goes into the background.
 @discussion Changes the flushing behavior of the library. If set to NO, the The library will not flush the data points when going into the background. Defaults to YES.
 */
@property(nonatomic, assign) BOOL flushOnBackground;

/*! @property nameTag
 @abstract The name tag of the current user.
 @discussion The name tag is a human readable string that identifies the user.
 */
@property(nonatomic, retain) NSString *nameTag;

/*! @property testMode
	@abstract Whether test mode is on
	@discussion Changing this value enables/disables test mode for future flushes.
*/
@property(nonatomic) BOOL testMode;


/*! @property serverURL
 @abstract The Mixpanel API endpoint 
 @discussion Allows setting a custom API URL. Defaults to http://api.mixpanel.com/track/
 */
@property(retain) NSString *serverURL;


/*! @property delegate
 @abstract The Mixpanel API delegate 
 @discussion Allows finer grain control over uploading events.
 */
@property(assign) id<MixpanelDelegate> delegate;

/*! @property sendDeviceModel
 @abstract Tells the Mixpane API to send the device model as a super property.
 @discussion Tells the Mixpane API to send the device model as a super property.
 */
@property(nonatomic, assign) BOOL sendDeviceModel;
/*!
    @method     sharedAPIWithToken:
    @abstract   Initializes the API with your API Token. Returns the shared API object.
    @discussion	Initializes the MixpanelAPI object with your authentication token. 
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
 @discussion	Initializes an instance of the MixpanelAPI object with your authentication token. 
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
 @method		registerSuperProperties:
 @abstract	Registers a set of super properties for all event types.
 @discussion	Registers a set of super properties, overwriting property values if they already exist. 
 Super properties are added to all the data points. 				
 The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.	
 @param		properties a NSDictionary with the super properties to register.
 properties that will be registered with both events and funnels.
 
 */
- (void)registerSuperProperties:(NSDictionary*) properties;

/*!
 @method     registerSuperPropertiesOnce:
 @abstract   Registers a set of super properties unless the property already exists.
 @discussion Registers a set of super properties, without overwriting existing key\value pairs. 
 Super properties are added to all the data points.
 The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
 @param		properties a NSDictionary with the super properties to register.
 properties that will be registered with both events and funnels.
 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties;

/*!
 @method     registerSuperPropertiesOnce:defaultValue:
 @abstract   Registers a set of super properties without overwriting existing values unless the existing value is equal to defaultValue.
 @discussion Registers a set of super properties, without overwriting existing key\value pairs. If the value of an existing property is equal to defaultValue, 
 then this method will update the value of that property.  Super properties are added to all the data points.
 The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
 @param		properties a NSDictionary with the super properties to register.
 @param      defaultValue If an existing property is equal to defaultValue, the value of said property gets updated.
 
 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties defaultValue:(id) defaultValue;

/*!
	@method     identifyUser:
	@abstract   Identifies a user.
	@discussion Identifies a user throughout an application run. By default the UDID of the device is used as an identifier.
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		identity A string to use as a user identity.
 */
- (void)identifyUser:(NSString*) identity;

/*!
	@method		track:
	@abstract   Tracks an event.
	@discussion Tracks an event. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeEvent</code> get attached to events.
				If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		event The event to track.
 */
- (void)track:(NSString*) event;

/*!
	@method     track:properties:
	@abstract   Tracks an event with properties.
	@discussion Tracks an event. The properties of this event are a union of the super properties of type Super properties of type 
				<code>kMPLibEventTypeAll</code>, <code>kMPLibEventTypeEvent</code> and the <code>properties</properties> parameter. 
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		event The event to track. If this event is a funnel step specified by <code>trackFunnel:steps:</code> It will also be tracked as a funnel.
	@param		properties The properties for this event. The keys must be NSString objects and the values should be NSString or NSNumber objects.
 */
- (void)track:(NSString*) event properties:(NSDictionary*) properties;


/*!
 @method     flush
 @abstract   Uploads datapoints to the Mixpanel Server.
 @discussion Uploads datapoints to the Mixpanel Server.
 */
- (void)flush;
@end
