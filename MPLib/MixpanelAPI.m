//
//  MixpanelLib.m
//  MPLib
//
//
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import "MixpanelAPI.h"
#import "MixpanelEvent.h"
#import "CJSONDataSerializer.h"
#import "NSData+Base64.h"

#define SERVER_URL @"http://api.mixpanel.com/track/"
#define FILE_PATH [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"MixPanelLib_SavedData.plist"]
@interface MixpanelAPI ()
@property(nonatomic,copy) NSString *apiToken;
@property(nonatomic,retain) NSMutableDictionary *superProperties;
@property(nonatomic,retain) NSMutableDictionary *eventSuperProperties;
@property(nonatomic,retain) NSMutableDictionary *funnelSuperProperties;
@property(nonatomic,retain) NSMutableDictionary *funnels;
@property(nonatomic,retain) NSArray *eventsToSend;
@property(nonatomic,retain) NSMutableArray *eventQueue;
@property(nonatomic,retain) NSURLConnection *connection;
@property(nonatomic,retain) NSMutableData *responseData;
@property(nonatomic,retain) NSString *defaultUserId;
-(void)flush;
-(void)unarchiveData;
-(void)archiveData;
-(void)applicationWillTerminate:(NSNotification *)notification;
-(void)applicationWillEnterForeground:(NSNotificationCenter *)notification;
-(void)applicationDidEnterBackground:(NSNotificationCenter *)notification;
@end

@implementation MixpanelAPI
@synthesize apiToken;
@synthesize superProperties;
@synthesize eventSuperProperties;
@synthesize funnelSuperProperties;
@synthesize eventQueue;
@synthesize eventsToSend;
@synthesize connection;
@synthesize responseData;
@synthesize funnels;
@synthesize defaultUserId;
@synthesize uploadInterval;
@synthesize flushOnBackground;
@synthesize testMode;
static MixpanelAPI *sharedInstance = nil; 
NSString* calculateHMAC_SHA1(NSString *str, NSString *key) {
	const char *cStr = [str UTF8String];
	const char *cSecretStr = [key UTF8String];
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	memset((void *)digest, 0x0, CC_SHA1_DIGEST_LENGTH);
	CCHmac(kCCHmacAlgSHA1, cSecretStr, strlen(cSecretStr), cStr, strlen(cStr), digest);
	return [NSString stringWithFormat:
			@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			digest[0],  digest[1],  digest[2],  digest[3],
			digest[4],  digest[5],  digest[6],  digest[7],
			digest[8],  digest[9],  digest[10], digest[11],
			digest[12], digest[13], digest[14], digest[15],
			digest[16], digest[17], digest[18], digest[19],
			digest[20], digest[21], digest[22], digest[23]
			];
}

+ (void)initialize
{
    if (sharedInstance == nil)
        sharedInstance = [[self alloc] init];
}
- (void) setUploadInterval:(NSUInteger) newInterval {
    uploadInterval = newInterval;
    if (timer) {
        [timer invalidate];
        [timer release];
        timer = nil;
    }
    [self flush];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:uploadInterval 
                                             target:self 
                                           selector:@selector(flush) 
                                           userInfo:nil 
                                            repeats:YES];
    [timer retain];
}
- (void) start {
    self.defaultUserId = calculateHMAC_SHA1([[UIDevice currentDevice] uniqueIdentifier], self.apiToken);
    [self identifyUser:self.defaultUserId];
    [self unarchiveData];

    [self setUploadInterval:uploadInterval];
}
+ (id)sharedAPIWithToken:(NSString*)apiToken
{
	sharedInstance.apiToken = apiToken;
	[sharedInstance start];
    //Already set by +initialize.
    return sharedInstance;
}
+ (id)sharedAPI
{
	return sharedInstance;
}
+ (id)allocWithZone:(NSZone*)zone
{
    //Usually already set by +initialize.
    if (sharedInstance) {
        //The caller expects to receive a new object, so implicitly retain it
        //to balance out the eventual release message.
        return [sharedInstance retain];
    } else {
        //When not already set, +initialize is our caller.
        //It's creating the shared instance, let this go through.
        return [super allocWithZone:zone];
    }
}

- (id)init
{
    //If sharedInstance is nil, +initialize is our caller, so initialize the instance.
    //If it is not nil, simply return the instance without re-initializing it.
    if (sharedInstance == nil) {
        if ((self = [super init])) {
			self.eventQueue = [NSMutableArray array];
			self.superProperties = [NSMutableDictionary dictionary];
			self.eventSuperProperties = [NSMutableDictionary dictionary];
			self.funnelSuperProperties = [NSMutableDictionary dictionary];
			self.funnels = [NSMutableDictionary dictionary];
			self.flushOnBackground = YES;
			uploadInterval = kMPUploadInterval;
			[self.superProperties setObject:@"iphone" forKey:@"mp_lib"];
			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000		
			if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)] && &UIBackgroundTaskInvalid) {

				taskId = UIBackgroundTaskInvalid;
				if (&UIApplicationDidEnterBackgroundNotification) {
				  [notificationCenter addObserver:self 
										 selector:@selector(applicationDidEnterBackground:) 
											 name:UIApplicationDidEnterBackgroundNotification 
										   object:nil];
				}
				if (&UIApplicationWillEnterForegroundNotification) {
				  [notificationCenter addObserver:self 
										 selector:@selector(applicationWillEnterForeground:) 
											 name:UIApplicationWillEnterForegroundNotification 
										   object:nil];
				}
			}
#endif
			[notificationCenter addObserver:self 
								   selector:@selector(applicationWillTerminate:) 
									   name:UIApplicationWillTerminateNotification 
									 object:nil];

			[self applicationWillEnterForeground:nil];
            //Initialize the instance here.
        }
    }
    return self;
}

- (void)registerSuperProperties:(NSDictionary*) properties
{
	[self registerSuperProperties:properties eventType:kMPLibEventTypeAll];
}

- (void)registerSuperProperties:(NSDictionary*) properties eventType:(MPLibEventType) type
{
	NSAssert(properties != nil, @"Properties should not be nil");
	NSMutableDictionary *superProps = nil;
	switch (type) {
		case kMPLibEventTypeEvent:
			superProps = self.eventSuperProperties;
			break;
		case kMPLibEventTypeFunnel:
			superProps = self.funnelSuperProperties;
			break;
		case kMPLibEventTypeAll:
			superProps = self.superProperties;
			break;
	}
	[superProps addEntriesFromDictionary:properties];
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties
{
	[self registerSuperPropertiesOnce:properties eventType:kMPLibEventTypeAll];
}

- (void)registerSuperPropertiesOnce:(NSDictionary*) properties eventType:(MPLibEventType) type
{
	NSMutableDictionary *superProps = nil;
	switch (type) {
		case kMPLibEventTypeEvent:
			superProps = self.eventSuperProperties;
			break;
		case kMPLibEventTypeFunnel:
			superProps = self.funnelSuperProperties;
			break;
		case kMPLibEventTypeAll:
			superProps = self.superProperties;
			break;
	}
	for (NSString *key in properties) {
		if ([superProps objectForKey:key] == nil) {
			[superProps setObject:[properties objectForKey:key] forKey:key];
		}
	}
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties defaultValue:(id) defaultValue
{
	[self registerSuperPropertiesOnce:properties eventType:kMPLibEventTypeAll defaultValue:defaultValue];
}
- (void)registerSuperPropertiesOnce:(NSDictionary*) properties eventType:(MPLibEventType) type defaultValue:(id) defaultValue
{
	NSMutableDictionary *superProps = nil;
	switch (type) {
		case kMPLibEventTypeEvent:
			superProps = self.eventSuperProperties;
			break;
		case kMPLibEventTypeFunnel:
			superProps = self.funnelSuperProperties;
			break;
		case kMPLibEventTypeAll:
			superProps = self.superProperties;
			break;
	}
	for (NSString *key in properties) {
		id value = [superProps objectForKey:key];
		if (value == nil || [value isEqual:defaultValue]) {
			[superProps setObject:[properties objectForKey:key] forKey:key];
		}
	}
}

- (void)registerFunnel:(NSString*) funnel steps:(NSArray*) steps 
{
	[funnels setObject:steps forKey:funnel];
}

- (void)identifyUser:(NSString*) identifier
{
	[self registerSuperPropertiesOnce:[NSDictionary dictionaryWithObject:identifier forKey:@"distinct_id"] eventType:kMPLibEventTypeAll defaultValue:self.defaultUserId];
}

- (void)track:(NSString*) event
{
	[self track:event properties:nil];
}

- (void)track:(NSString*) event properties:(NSDictionary*) properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	[props addEntriesFromDictionary:eventSuperProperties];
	[props addEntriesFromDictionary:superProperties];
	[props addEntriesFromDictionary:properties];
	if (![props objectForKey:@"token"]) {
		[props setObject:apiToken forKey:@"token"];
	}
	NSDictionary *allProperties = [props copy];
	MixpanelEvent *mpEvent = [[MixpanelEvent alloc] initWithName:event 
															type:kMPLibEventTypeEvent
													  properties:allProperties];
	[eventQueue addObject:mpEvent];
	[mpEvent release];
	for (NSString *funnel in funnels) {
		NSArray *steps = [funnels objectForKey:funnel];
		NSInteger step = [steps indexOfObject:event];
		if (step != NSNotFound) {
			[self trackFunnel:funnel step:step + 1 goal:event properties:properties];
		}
	}
	[allProperties release];
}
- (void)trackFunnel:(NSString*) funnelName step:(NSInteger)step goal:(NSString*) goal
{
	[self trackFunnel:funnelName step:step goal:goal properties:nil];	
}
- (void)trackFunnel:(NSString*) funnelName step:(NSInteger)step goal:(NSString*) goal properties:(NSDictionary*) properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	[props addEntriesFromDictionary:funnelSuperProperties];
	[props addEntriesFromDictionary:superProperties];
	[props addEntriesFromDictionary:properties];
	if (![props objectForKey:@"token"]) {
		[props setObject:apiToken forKey:@"token"];
	}
	[props setObject:funnelName forKey:@"funnel"];
	[props setObject:[NSNumber numberWithInt:step] forKey:@"step"];
	[props setObject:goal forKey:@"goal"];
	MixpanelEvent *mpEvent = [[MixpanelEvent alloc] initWithName:@"mp_funnel"
															type:kMPLibEventTypeFunnel
													  properties:props];
	[eventQueue addObject:mpEvent];
	[mpEvent release];
}

#pragma mark -
#pragma mark Application Lifecycle Events
- (void)unarchiveData {
	self.eventQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:FILE_PATH];
	if (!self.eventQueue) {
		self.eventQueue = [NSMutableArray array];
	}		
}
- (void)archiveData {
	if (![NSKeyedArchiver archiveRootObject:eventQueue toFile:FILE_PATH]) {
		NSLog(@"Unable to archive data!!!");
	}
}
- (void)applicationWillTerminate:(NSNotification*) notification
{
	[self archiveData];
}

- (void)applicationDidEnterBackground:(NSNotificationCenter*) notification
{
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
  if ([self flushOnBackground]) {
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)] &&
        [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)]) {
      taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.connection cancel];
        [self archiveData];
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
      }]	;
      [self flush];
    } else {
      [self archiveData];
    }
  } else {
    [self archiveData];
  }
	#endif
}
- (void)applicationWillEnterForeground:(NSNotificationCenter*) notification
{
	if (self.apiToken) {
		[self unarchiveData];
		[self flush];
	}
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid) {
		taskId = UIBackgroundTaskInvalid;				
	}
	#endif
}

#pragma mark -
#pragma mark Timer Callback and Networking code
- (void)flush
{
	if ([self.eventQueue count] == 0 || self.connection != nil) { // No events or already pushing data.
		return;
	} else if ([self.eventQueue count] > 50) {
		self.eventsToSend = [self.eventQueue subarrayWithRange:NSMakeRange(0, 50)];
	} else {
		self.eventsToSend = [NSArray arrayWithArray:self.eventQueue];
	}
	
	CJSONDataSerializer *serializer = [CJSONDataSerializer serializer];
	NSData *data = [serializer serializeArray:[eventsToSend valueForKey:@"dictionaryValue"]
										   error:nil];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	NSString *urlString = SERVER_URL;
	NSString *postBody = [NSString stringWithFormat:@"ip=1&data=%@", [data base64EncodedString]];
	if (self.testMode) {
		NSLog(@"Mixpanel test mode is enabled");
		postBody = [NSString stringWithFormat:@"test=1&%@", postBody];
	}
	NSURL *url = [NSURL URLWithString:urlString];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	[request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];  
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	[self.connection start];
	[request release];
	
}

#pragma mark -
#pragma mark NSURLConnection Callbacks
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	if ([response statusCode] != 200) {
		NSLog(@"fail %@", [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]);
	} else {
		self.responseData = [NSMutableData data];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{
	[self.responseData appendData:data];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
	NSLog(@"error, clean up %@", error);
	self.eventsToSend = nil;
	self.responseData = nil;
	self.connection = nil;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] && taskId != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
	}
	#endif
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection 
{
	NSString *response = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
	NSInteger result = [response intValue];
    
    [self.eventQueue removeObjectsInArray:self.eventsToSend];
	
    if (result == 0) {
		NSLog(@"failed %@", response);
	}
    
    [response release];
	[self archiveData]; //update saved archive
	self.eventsToSend = nil;
	self.responseData = nil;
	self.connection = nil;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] && taskId != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
	}
#endif
}
@end
