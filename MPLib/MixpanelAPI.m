//
//  MixpanelLib.m
//  MPLib
//
//
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import "MixpanelAPI.h"
#import "MixpanelEvent.h"
#import "MPCJSONDataSerializer.h"
#import "NSData+MPBase64.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <errno.h>
#include <net/if_dl.h>
#include <sys/sysctl.h>
#if ! defined(IFT_ETHER)
#define IFT_ETHER 0x6/* Ethernet CSMACD */
#endif
#define kMPNameTag @"mp_name_tag"
#define kMPDeviceModel @"mp_device_model"
@interface MixpanelAPI ()
@property(nonatomic,copy) NSString *apiToken;
@property(nonatomic,retain) NSMutableDictionary *superProperties;
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
@synthesize eventQueue;
@synthesize eventsToSend;
@synthesize connection;
@synthesize responseData;
@synthesize defaultUserId;
@synthesize uploadInterval;
@synthesize flushOnBackground;
@synthesize serverURL;
@synthesize delegate;
@synthesize testMode;
@synthesize sendDeviceModel;
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
			digest[16], digest[17], digest[18], digest[19]
			];
}

NSString* getPlatform()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
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

- (void)setNameTag:(NSString *)nameTag
{
    [[self superProperties] setObject:nameTag forKey:kMPNameTag];
}
- (NSString*)nameTag
{
    return [[self superProperties] objectForKey:kMPNameTag];
}
- (NSDictionary *)interfaces
{
    NSMutableDictionary *theDictionary = [NSMutableDictionary dictionary];
    
    
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    const struct sockaddr_dl * dlAddr;
    const uint8_t * base;
    
    success = getifaddrs(&addrs) == 0;
    if (success)
    {
        cursor = addrs;
        while (cursor != NULL)
        {
            if ( (cursor->ifa_addr->sa_family == AF_LINK) && (((const struct sockaddr_dl *)cursor->ifa_addr)->sdl_type == IFT_ETHER) )
            {
                //        fprintf(stderr, "%s:", cursor->ifa_name);
                dlAddr = (const struct sockaddr_dl *)cursor->ifa_addr;
                base = (const uint8_t *) &dlAddr->sdl_data[dlAddr->sdl_nlen];
                
                NSString *theKey = [NSString stringWithUTF8String:cursor->ifa_name];
                NSString *theValue = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", base[0], base[1], base[2], base[3], base[4], base[5]];
                [theDictionary setObject:theValue forKey:theKey];
            }
            
            cursor = cursor->ifa_next;
        }
        
        freeifaddrs(addrs);
    }
    
    return(theDictionary);
    
}
- (NSString*) userIdentifier
{
    NSDictionary *dict = [self interfaces];
    NSArray *keys = [dict allKeys];
    keys = [keys  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
 
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
 
    /* while most apps will define CFBundleName, it's not guaranteed -- an app can choose to define it or not
       so when it's missing, use the bundle file name */	
    if (bundleName == nil) {
        bundleName = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
    }

    NSMutableString *string = [NSMutableString stringWithString:bundleName];	
    for (NSString *key in keys) {
        [string appendString:[dict objectForKey:key]];
    }
    return string;
}
- (void) start {
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
    
    self.defaultUserId = calculateHMAC_SHA1([self userIdentifier], self.apiToken);
    [self identifyUser:self.defaultUserId];
    [self unarchiveData];
    [self flush];
    [self setUploadInterval:uploadInterval];
}

- (void) stop {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    [timer release];
    timer = nil;
    [self archiveData];
}

- (void)setSendDeviceModel:(BOOL)sd
{
    sendDeviceModel = sd;
    if (sd) {
        [[self superProperties] setObject:getPlatform() forKey:kMPDeviceModel];
    } else {
        [[self superProperties] removeObjectForKey:kMPDeviceModel];
    }
}
+ (id)sharedAPIWithToken:(NSString*)apiToken
{
    //Already set by +initialize.
    sharedInstance.apiToken = apiToken;
    [sharedInstance start];
    return sharedInstance;
}
+ (id)sharedAPI
{
	return sharedInstance;
}

- (id)initWithToken:(NSString *)aToken
{
    if ((self = [self init])) {
        apiToken = [aToken retain];
        [self start];
    }
    return  self;
}
- (id)init
{
    //If sharedInstance is nil, +initialize is our caller, so initialize the instance.
    //If it is not nil, simply return the instance without re-initializing it.

    if ((self = [super init])) {
        eventQueue = [[NSMutableArray alloc] init];
        superProperties = [[NSMutableDictionary alloc] init];
        flushOnBackground = YES;
        serverURL = @"https://api.mixpanel.com/track/";
        uploadInterval = kMPUploadInterval;
        [self.superProperties setObject:@"iphone" forKey:@"mp_lib"];
        
        //Initialize the instance here.
    }

    return self;
}

- (void)registerSuperProperties:(NSDictionary*) properties
{
    NSAssert(properties != nil, @"Properties should not be nil");
    [self.superProperties addEntriesFromDictionary:properties];
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties
{
    NSMutableDictionary *superProps = self.superProperties;
    for (NSString *key in properties) {
        if ([superProps objectForKey:key] == nil) {
            [superProps setObject:[properties objectForKey:key] forKey:key];
        }
    }
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties defaultValue:(id) defaultValue
{
    NSMutableDictionary *superProps = self.superProperties;
    for (NSString *key in properties) {
        id value = [superProps objectForKey:key];
        if (value == nil || [value isEqual:defaultValue]) {
            [superProps setObject:[properties objectForKey:key] forKey:key];
        }
    }
}


- (void)identifyUser:(NSString*) identifier
{
	[self registerSuperPropertiesOnce:[NSDictionary dictionaryWithObject:identifier forKey:@"distinct_id"] defaultValue:self.defaultUserId];
}

- (NSString*) filePath 
{
    if (self == sharedInstance) return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"MixPanelLib_SavedData.plist"];
    
    NSString *filename = [NSString stringWithFormat:@"MPLib_%@_SavedData.plist", [self apiToken]];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:filename];
}

- (void)track:(NSString*) event
{
	[self track:event properties:nil];
}

- (void)track:(NSString*) event properties:(NSDictionary*) properties
{
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	[props addEntriesFromDictionary:superProperties];
	[props addEntriesFromDictionary:properties];
	if (![props objectForKey:@"token"]) {
		[props setObject:apiToken forKey:@"token"];
	}
	NSDictionary *allProperties = [props copy];
	MixpanelEvent *mpEvent = [[MixpanelEvent alloc] initWithName:event 
                                                      properties:allProperties];
	[[self eventQueue] addObject:mpEvent];
	[mpEvent release];
	[allProperties release];
}

#pragma mark -
#pragma mark Application Lifecycle Events
- (void)unarchiveData {
	self.eventQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]];
	if (!self.eventQueue) {
		self.eventQueue = [NSMutableArray array];
	}		
}
- (void)archiveData {
	if (![NSKeyedArchiver archiveRootObject:[self eventQueue] toFile:[self filePath]]) {
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
                taskId = UIBackgroundTaskInvalid;
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
    if (taskId != UIBackgroundTaskInvalid) {
      [[UIApplication sharedApplication] endBackgroundTask:taskId];
    }
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
	if ([self.delegate respondsToSelector:@selector(mixpanel:willUploadEvents:)]) {
        if (![self.delegate mixpanel:self willUploadEvents:self.eventsToSend]) {
            self.eventsToSend = nil;
            return;            
        }

    }

	MPCJSONDataSerializer *serializer = [MPCJSONDataSerializer serializer];
	NSData *data = [serializer serializeArray:[eventsToSend valueForKey:@"dictionaryValue"]
                                        error:nil];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    NSString *b64String = [data mp_base64EncodedString];
    b64String = (id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                    (CFStringRef)b64String,
                                                                    NULL,
                                                                    CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                    kCFStringEncodingUTF8);
    [b64String autorelease];
	NSString *postBody = [NSString stringWithFormat:@"ip=1&data=%@", b64String];
	if (self.testMode) {
		NSLog(@"Mixpanel test mode is enabled");
		postBody = [NSString stringWithFormat:@"test=1&%@", postBody];
	}
	NSURL *url = [NSURL URLWithString:[self serverURL]];
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
    if ([self.delegate respondsToSelector:@selector(mixpanel:didFailToUploadEvents:withError:)]) {
        [self.delegate mixpanel:self didFailToUploadEvents:self.eventsToSend withError:error];
    }
	self.eventsToSend = nil;
	self.responseData = nil;
	self.connection = nil;
    [self archiveData];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] && taskId != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
    taskId = UIBackgroundTaskInvalid;
	}

#endif
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection 
{
    if ([self.delegate respondsToSelector:@selector(mixpanel:didUploadEvents:)]) {
        [self.delegate mixpanel:self didUploadEvents:self.eventsToSend];
    }
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
    taskId = UIBackgroundTaskInvalid;
	}
#endif
}

- (void)dealloc
{
    [self archiveData];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [apiToken release], apiToken = nil;
    [eventQueue release], eventQueue = nil;
    [superProperties release], superProperties = nil;
    [timer invalidate], [timer release], timer = nil;
    [eventsToSend release], eventsToSend = nil;
    [responseData release], responseData = nil;
    [connection release], connection = nil;
    [defaultUserId release], defaultUserId = nil;
    [super dealloc];
}
@end
