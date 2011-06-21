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

/*!
    @const		kMPUploadInterval
    @abstract   The default number of seconds between data uploads to the Mixpanel server
    @discussion The default number of seconds between data uploads to the Mixpanel server
*/
static const NSUInteger kMPUploadInterval = 30;
/*!
    @enum 
    @abstract   An enumeration of the supported event types.
    @discussion MPLibEventType is used to scope super properties to specific event types. 
    @constant   kMPLibEventTypeEvent - Scope super properties to events.
    @constant   kMPLibEventTypeFunnel - Scope super properties to funnels.
    @constant   kMPLibEventTypeAll - Scope super properties to funnels and events.
*/
typedef enum {
	kMPLibEventTypeEvent = 1,
	kMPLibEventTypeFunnel = 2,
	kMPLibEventTypeAll = 3
} MPLibEventType;

/*!
    @class		MixpanelAPI
    @abstract	Main entry point for the Mixpanel API.
    @discussion With MixpanelAPI you can log events and analyze funnels using the Mixpanel dashboard.
*/
@interface MixpanelAPI : NSObject {
	NSString *apiToken;
	NSMutableArray *eventQueue;
	NSMutableDictionary *superProperties;
	NSMutableDictionary *eventSuperProperties;
	NSMutableDictionary *funnelSuperProperties;
	NSMutableDictionary *funnels;
	NSTimer *timer;
	NSArray *eventsToSend;
	NSMutableData *responseData;
	NSURLConnection *connection;
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	UIBackgroundTaskIdentifier taskId;
	#endif
	NSString *defaultUserId;
	NSUInteger uploadInterval;
	BOOL testMode;
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

/*! @property testMode
	@abstract Whether test mode is on
	@discussion Changing this value enables/disables test mode for future flushes.
*/
@property(nonatomic) BOOL testMode;

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
	@method		registerSuperProperties:eventType:
	@abstract	Registers a set of super properties for a specified event type.
	@discussion	Registers a set of super properties, overwriting property values if they already exist. 
				Super properties are added to all the data points of the specified event type. 				
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.	
	@param		properties a NSDictionary with the super properties to register.
	@param		eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
				properties that will be registered with both events and funnels.
	
 */
- (void)registerSuperProperties:(NSDictionary*) properties eventType:(MPLibEventType) eventType;


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
	@method     registerSuperPropertiesOnce:eventType:
	@abstract   Registers a set of super properties for a specified event type unless the property already exists.
	@discussion Registers a set of super properties, without overwriting existing key\value pairs. 
				Super properties are added to all the data points of the specified event type.
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		properties a NSDictionary with the super properties to register.
	@param		eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
				properties that will be registered with both events and funnels.
 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties eventType:(MPLibEventType) eventType;


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
	@method     registerSuperPropertiesOnce:eventType:defaultValue:
	@abstract   Registers a set of super properties for a specified event type without overwriting existing values unless the existing value is equal to defaultValue.
	@discussion Registers a set of super properties, without overwriting existing key\value pairs. If the value of an existing property is equal to defaultValue, 
				then this method will update the value of that property.
				Super properties are added to all the data points of the specified event type.
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		properties a NSDictionary with the super properties to register.
	@param		eventType The event type to register the properties with. Use kMPLibEventTypeAll for 
				properties that will be registered with both events and funnels.
	@param      defaultValue If an existing property is equal to defaultValue, the value of said property gets updated.

 */
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties eventType:(MPLibEventType) eventType defaultValue:(id) defaultValue;

/*!
	@method     registerFunnel:steps:
	@abstract   Registers a funnel.
	@discussion Registers a funnel with an array of events to use as steps. This method simplifies funnel tracking by preregistering 
				a funnel. After calling this method, you can track funnels by calling the track: or track:properties: methods with an event specified in steps.
				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		funnel The name of the funnel to register
	@param		steps An array of NSString objects with the events to use as steps for this funnel.
 */
- (void)registerFunnel:(NSString*) funnel steps:(NSArray*) steps;

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
	@method     trackFunnel:step:goal:
	@abstract   Tracks a funnel step. 
	@discussion Tracks a funnel step.
 				The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	@param		funnelName The name for this funnel. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeFunnel</code> get attached to events.
	@param		step The step number of the step you are tracking. Step numbers start at 1.
	@param		goal A Human readable name for this funnel step.
 */
- (void)trackFunnel:(NSString*) funnelName step:(NSInteger)step goal:(NSString*) goal;

/*!
	 @method     trackFunnel:step:goal:properties:
	 @abstract   Tracks a funnel step with properties.
	 @discussion Tracks a funnel step with properties. The properties of this funnel step are a union of the super properties of type Super properties of type 
				 The API must be initialized with <code>sharedAPIWithToken:</code> before calling this method.
	 <code>kMPLibEventTypeAll</code>, <code>kMPLibEventTypeFunnel</code> and the <code>properties</properties> parameter. 
	 @param		funnelName The name for this funnel. Super properties of type <code>kMPLibEventTypeAll</code> and <code>kMPLibEventTypeFunnel</code> get attached to events.
	 @param		step The step number of the step you are tracking. Step numbers start at 1.
	 @param		goal A Human readable name for this funnel step.
	 @param		properties The properties for this event. The keys must be NSString objects and the values should be NSString or NSNumber objects.
 */
- (void)trackFunnel:(NSString*) funnelName step:(NSInteger)step goal:(NSString*) goal properties:(NSDictionary*) properties;

/*!
 @method     flush
 @abstract   Uploads datapoints to the Mixpanel Server.
 @discussion Uploads datapoints to the Mixpanel Server.
 */
- (void)flush;
@end
