//
//  MixpanelAPI.m
//  MPLib
//
//
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import "MixpanelAPI.h"
#import "MixpanelAPI_Private.h"
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
#define kMPDeviceModel @"mp_device_model" /* Kept for compatibility */
#define kMPDevicePlatform @"$ios_device_model"
#define kMPOSVersion @"$ios_version"
#define kMPAppVersion @"$ios_app_version"

@implementation MixpanelAPI
@synthesize apiToken;
@synthesize superProperties;
@synthesize eventQueue;
@synthesize peopleQueue;
@synthesize eventsToSend;
@synthesize peopleToSend;
@synthesize connection;
@synthesize peopleConnection;
@synthesize responseData;
@synthesize peopleResponseData;
@synthesize defaultUserId;
@synthesize uploadInterval;
@synthesize flushOnBackground;
@synthesize serverURL;
@synthesize delegate;
@synthesize testMode;
@synthesize sendDeviceModel;

static MixpanelAPI *sharedInstance = nil; 

+ (NSString*)calculateHMAC_SHA1withString:(NSString*) str andKey:(NSString*)key {
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

+ (NSString*)currentPlatform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

+ (void)initialize {
    if (sharedInstance == nil)
        sharedInstance = [[self alloc] init];
}

- (void)setUploadInterval:(NSUInteger) newInterval {
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

- (void)setNameTag:(NSString *)nameTag {
    if(nameTag == nil) {
        [[self superProperties] removeObjectForKey:kMPNameTag];
    } else {
        [[self superProperties] setObject:nameTag forKey:kMPNameTag];
    }
}

- (NSString*)nameTag {
    return [[self superProperties] objectForKey:kMPNameTag];
}

- (NSDictionary*)interfaces {
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

- (NSString*)userIdentifier {
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

- (void)start {
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
    
    self.defaultUserId = [MixpanelAPI calculateHMAC_SHA1withString:[self userIdentifier] andKey:self.apiToken];
    [self identifyUser:self.defaultUserId];
    [self unarchiveData];
    [self flush];
    [self setUploadInterval:uploadInterval];
    [self setSendDeviceModel:YES];
}

- (void)stop {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    [timer release];
    timer = nil;
    [self archiveData];
}

- (void)setSendDeviceModel:(BOOL)sd {
    sendDeviceModel = sd;
    if (sd) {
        [[self superProperties] setObject:[MixpanelAPI currentPlatform] forKey:kMPDeviceModel];
        [[self superProperties] setObject:[[UIDevice currentDevice] systemVersion] forKey:kMPOSVersion];
        [[self superProperties] setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
                                   forKey:kMPAppVersion];
    } else {
        [[self superProperties] removeObjectForKey:kMPDeviceModel];
        [[self superProperties] removeObjectForKey:kMPOSVersion];
        [[self superProperties] removeObjectForKey:kMPAppVersion];
    }
}

+ (id)sharedAPIWithToken:(NSString*)apiToken {
    //Already set by +initialize.
    sharedInstance.apiToken = apiToken;
    [sharedInstance start];
    return sharedInstance;
}

+ (id)sharedAPI {
	return sharedInstance;
}

- (id)initWithToken:(NSString *)aToken {
    if ((self = [self init])) {
        apiToken = [aToken retain];
        [self start];
    }
    return  self;
}

- (id)init {
    //If sharedInstance is nil, +initialize is our caller, so initialize the instance.
    //If it is not nil, simply return the instance without re-initializing it.

    if ((self = [super init])) {
        eventQueue = [[NSMutableArray alloc] init];
        peopleQueue = [[NSMutableArray alloc] init];
        superProperties = [[NSMutableDictionary alloc] init];
        flushOnBackground = YES;
        serverURL = @"https://api.mixpanel.com";
        uploadInterval = kMPUploadInterval;
        [self.superProperties setObject:@"iphone" forKey:@"mp_lib"];        
    }

    return self;
}

- (void)registerSuperProperties:(NSDictionary*) properties {
    NSAssert(properties != nil, @"Properties should not be nil");
    [self.superProperties addEntriesFromDictionary:properties];
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties {
    NSMutableDictionary *superProps = self.superProperties;
    for (NSString *key in properties) {
        if ([superProps objectForKey:key] == nil) {
            [superProps setObject:[properties objectForKey:key] forKey:key];
        }
    }
}


- (void)registerSuperPropertiesOnce:(NSDictionary*) properties defaultValue:(id) defaultValue {
    NSMutableDictionary *superProps = self.superProperties;
    for (NSString *key in properties) {
        id value = [superProps objectForKey:key];
        if (value == nil || [value isEqual:defaultValue]) {
            [superProps setObject:[properties objectForKey:key] forKey:key];
        }
    }
}

- (void)identifyUser:(NSString*) identifier {
    [self registerSuperProperties:[NSDictionary dictionaryWithObject:identifier forKey:@"distinct_id"]];
}

- (NSString*)eventFilePath  {
    if (self == sharedInstance) return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"MixPanelLib_SavedData.plist"];
    
    NSString *filename = [NSString stringWithFormat:@"MPLib_%@_SavedData.plist", [self apiToken]];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:filename];
}

- (NSString*)peopleFilePath {
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:@"MixPanelLib_SavedPeople.plist"];
}

- (void)track:(NSString*) event {
	[self track:event properties:nil];
}

- (void)track:(NSString*) event properties:(NSDictionary*) properties {
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	[props addEntriesFromDictionary:superProperties];
	[props addEntriesFromDictionary:properties];
	if (![props objectForKey:@"token"]) {
        if (!apiToken)
            [NSException raise:@"Mixpanel API token not set" format:@"The token must be specified before making API calls."];

		[props setObject:apiToken forKey:@"token"];
	}
	NSDictionary *allProperties = [props copy];
	MixpanelEvent *mpEvent = [[MixpanelEvent alloc] initWithName:event 
                                                      properties:allProperties];
	[[self eventQueue] addObject:mpEvent];
	[mpEvent release];
	[allProperties release];
}

- (void)addPersonToQueueWithAction:(NSString*)action andProperties:(NSDictionary*)properties {
    NSMutableDictionary *person = [NSMutableDictionary dictionary];
    NSMutableDictionary *mutable_properties = [[properties mutableCopy] autorelease];
    
    if ([mutable_properties objectForKey:@"$token"]) {
        [person setObject:[mutable_properties objectForKey:@"$token"] forKey:@"$token"];
        [mutable_properties removeObjectForKey:@"$token"];
    } else {
        if (!apiToken)
            [NSException raise:@"Mixpanel API token not set" format:@"The token must be specified before making API requests."];
        
        [person setObject:apiToken forKey:@"$token"];
    }
    
    if ([mutable_properties objectForKey:@"$distinct_id"]) {
        [person setObject:[mutable_properties objectForKey:@"$distinct_id"] forKey:@"$distinct_id"];
        [mutable_properties removeObjectForKey:@"$distinct_id"];
    } else {
        if (![superProperties objectForKey:@"distinct_id"])
            [NSException raise:@"Mixpanel $distinct_id not set" format:@"The $distinct_id must be specified before making people API requests. Call start or identifyUser before making requests."];
        [person setObject:[superProperties objectForKey:@"distinct_id"] forKey:@"$distinct_id"];
    }
    
    if ([mutable_properties objectForKey:@"$time"]) {
        [person setObject:[mutable_properties objectForKey:@"$time"] forKey:@"$time"];
        [mutable_properties removeObjectForKey:@"$time"];
    } else {
        [person setObject:
                [NSNumber numberWithLongLong:(long long)([[NSDate date] timeIntervalSince1970]*1000)]
                forKey:@"$time"];
    }
    
    if (sendDeviceModel) {
        NSString *platform = [MixpanelAPI currentPlatform];
        NSString *os_version = [[UIDevice currentDevice] systemVersion];
        NSString *app_version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

        if ([action isEqualToString:@"$set"]) {
            [mutable_properties setObject:platform forKey:kMPDevicePlatform];
            [mutable_properties setObject:os_version forKey:kMPOSVersion];
            [mutable_properties setObject:app_version forKey:kMPAppVersion];
        } else if ([action isEqualToString:@"$union"]) {
            [self addPersonToQueueWithAction:@"$set" andProperties:[NSDictionary dictionary]];
        }
    }

    [person setObject:[[mutable_properties copy] autorelease] forKey:action];
    [[self peopleQueue] addObject:person];
}

- (void)setUserProperties:(NSDictionary*)properties {
    [self addPersonToQueueWithAction:@"$set" andProperties:properties];
}

- (void)setUserProperty:(id)property forKey:(NSString*)key {
    [self setUserProperties:[NSDictionary dictionaryWithObject:property forKey:key]];
}

- (void)incrementUserProperties:(NSDictionary*)properties {
    [self addPersonToQueueWithAction:@"$add" andProperties:properties];
}

- (void)incrementUserPropertyWithKey:(NSString*)key {
    [self incrementUserProperties:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:key]];
}

- (void)incrementUserPropertyWithKey:(NSString*)key byNumber:(NSNumber*)amount {
    [self incrementUserProperties:[NSDictionary dictionaryWithObject:amount forKey:key]];
}

- (void)incrementUserPropertyWithKey:(NSString*)key byInt:(int)amount {
    [self incrementUserPropertyWithKey:key byNumber:[NSNumber numberWithInt:amount]];
}

- (void)append:(id)item toUserPropertyWithKey:(NSString*)key {
    [self addPersonToQueueWithAction:@"$append" andProperties:[NSDictionary dictionaryWithObject:item forKey:key]];
}

- (void)deleteUser:(NSString*)distinctId {
    [self addPersonToQueueWithAction:@"$delete" andProperties:[NSDictionary dictionaryWithObject:distinctId forKey:@"$distinct_id"]];
}

- (void)deleteCurrentUser {
    [self addPersonToQueueWithAction:@"$delete" andProperties:[NSDictionary dictionary]];
}

#pragma mark -
#pragma mark Application Lifecycle Events
- (void)unarchiveData {
    [self unarchiveEvents];
    [self unarchivePeople];
}

- (void)unarchiveEvents {
    @try {
        self.eventQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:[self eventFilePath]];
    }
    @catch (NSException *exception) {
        NSLog(@"Unable to unarchive Mixpanel event data, starting fresh.");
        [[NSFileManager defaultManager] removeItemAtPath:[self eventFilePath] error:nil];
        self.eventQueue = nil;
    }

	if (!self.eventQueue) {
		self.eventQueue = [NSMutableArray array];
	}
}

- (void)unarchivePeople {
    @try {
        self.peopleQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:[self peopleFilePath]];
    }
    @catch (NSException *exception) {
        NSLog(@"Unable to unarchive Mixpanel people data, starting fresh.");
        [[NSFileManager defaultManager] removeItemAtPath:[self peopleFilePath] error:nil];
        self.peopleQueue = [NSMutableArray array];
    }

    if (!self.peopleQueue) {
        self.peopleQueue = [NSMutableArray array];
    }
}

- (void)archiveData {
    [self archiveEvents];
    [self archivePeople];
}

- (void)archiveEvents {
	if (![NSKeyedArchiver archiveRootObject:[self eventQueue] toFile:[self eventFilePath]]) {
		NSLog(@"Unable to archive Mixpanel event data!");
	}
}

- (void)archivePeople {
    if (![NSKeyedArchiver archiveRootObject:[self peopleQueue] toFile:[self peopleFilePath]]) {
        NSLog(@"Unable to archive Mixpanel people data!");
    }
}

- (void)applicationWillTerminate:(NSNotification*) notification {
	[self archiveData];
}

- (void)applicationDidEnterBackground:(NSNotificationCenter*) notification {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if ([self flushOnBackground]) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)] &&
            [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)]) {
            if (self.peopleQueue.count || self.eventQueue.count) {
                // There is something to send
                taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                    [self.connection cancel];
                    self.connection = nil;
                    [self.peopleConnection cancel];
                    self.peopleConnection = nil;
                    [self archiveData];
                    [[UIApplication sharedApplication] endBackgroundTask:taskId];
                    taskId = UIBackgroundTaskInvalid;
                }];
                [self flush];
            }
        } else {
            [self archiveData];
        }
    } else {
        [self archiveData];
    }
#endif
}

- (void)applicationWillEnterForeground:(NSNotificationCenter*) notification {
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
- (NSURLConnection*)apiConnectionWithEndpoint:(NSString*)endpoint andBody:(NSString*)body {
    NSURL *url = [NSURL URLWithString:[[self serverURL] stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    return [NSURLConnection connectionWithRequest:request delegate:self];
}

- (NSString*)encodedStringFromArray:(NSArray*)array {
    MPCJSONDataSerializer *serializer = [MPCJSONDataSerializer serializer];
    NSError *error = nil;
    NSData *data = [serializer serializeArray:array error:&error];
    if (error) {
        NSLog(@"%@", error);
        return @"";
    } else {
        NSString *b64String = [data mp_base64EncodedString];
        b64String = (id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                (CFStringRef)b64String,
                                                                NULL,
                                                                CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                kCFStringEncodingUTF8);
        return [b64String autorelease];
    }
}

- (void)flush {
    [self flushPeople];
    [self flushEvents];
}

- (void)flushPeople {
    if ([self.peopleQueue count] == 0 || self.peopleConnection != nil) {
        return;
    } else if ([self.peopleQueue count] > 50) {
        self.peopleToSend = [self.peopleQueue subarrayWithRange:NSMakeRange(0, 50)];
    } else {
        self.peopleToSend = [NSArray arrayWithArray:self.peopleQueue];
    }
    if ([self.delegate respondsToSelector:@selector(mixpanel:willUploadPeople:)]) {
        if (![self.delegate mixpanel:self willUploadPeople:self.peopleToSend]) {
            self.peopleToSend = nil;
            return;
        }
    }
    
    NSString *b64String = [self encodedStringFromArray:self.peopleToSend];
    NSString *postBody = [NSString stringWithFormat:@"ip=1&data=%@", b64String];

    self.peopleConnection = [self apiConnectionWithEndpoint:@"/engage/" andBody:postBody];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(self.connection || self.peopleConnection)];
}

- (void)flushEvents {
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
    
    NSString *b64String = [self encodedStringFromArray:[self.eventsToSend valueForKey:@"dictionaryValue"]];
	NSString *postBody = [NSString stringWithFormat:@"ip=1&data=%@", b64String];
	if (self.testMode) {
		NSLog(@"Mixpanel test mode is enabled");
		postBody = [NSString stringWithFormat:@"test=1&%@", postBody];
	}
    
	self.connection = [self apiConnectionWithEndpoint:@"/track/" andBody:postBody];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(self.connection || self.peopleConnection)];
}

#pragma mark -
#pragma mark NSURLConnection Callbacks
- (void)connection:(NSURLConnection *)_connection didReceiveResponse:(NSHTTPURLResponse *)response {
	if ([response statusCode] != 200) {
		NSLog(@"fail %@", [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]);
	} else if (_connection == self.connection) {
		self.responseData = [NSMutableData data];
	} else if (_connection == self.peopleConnection) {
        self.peopleResponseData = [NSMutableData data];
    }
}

- (void)connection:(NSURLConnection *)_connection didReceiveData:(NSData *)data {
    if (_connection == self.connection) {
        [self.responseData appendData:data];
    } else if (_connection == self.peopleConnection) {
        [self.peopleResponseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)_connection didFailWithError:(NSError *)error {
	NSLog(@"error, clean up %@", error);
    
    if (_connection == self.connection) {
        if ([self.delegate respondsToSelector:@selector(mixpanel:didFailToUploadEvents:withError:)]) {
            [self.delegate mixpanel:self didFailToUploadEvents:self.eventsToSend withError:error];
        }
        self.eventsToSend = nil;
        self.responseData = nil;
        self.connection = nil;
        [self archiveEvents];
    } else if (_connection == self.peopleConnection) {
        if ([self.delegate respondsToSelector:@selector(mixpanel:didFailToUploadPeople:withError:)]) {
            [self.delegate mixpanel:self didFailToUploadPeople:self.peopleToSend withError:error];
        }
        self.peopleToSend = nil;
        self.peopleResponseData = nil;
        self.peopleConnection = nil;
        [self archivePeople];
    }
    
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(self.connection || self.peopleConnection)];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] && taskId != UIBackgroundTaskInvalid && self.connection == nil && self.peopleConnection == nil) {
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
        taskId = UIBackgroundTaskInvalid;
	}

#endif
}

- (void)connectionDidFinishLoading:(NSURLConnection *)_connection {
    if (_connection == self.connection) {
        if ([self.delegate respondsToSelector:@selector(mixpanel:didUploadEvents:)]) {
            [self.delegate mixpanel:self didUploadEvents:self.eventsToSend];
        }
        NSString *response = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
        NSInteger result = [response intValue];
        
        [self.eventQueue removeObjectsInArray:self.eventsToSend];
        
        if (result == 0) {
            NSLog(@"sending events failed: %@", response);
        }
        
        [response release];
        [self archiveEvents]; //update saved archive
        self.eventsToSend = nil;
        self.responseData = nil;
        self.connection = nil;
    } else if (_connection == self.peopleConnection) {
        if ([self.delegate respondsToSelector:@selector(mixpanel:didUploadPeople:)]) {
            [self.delegate mixpanel:self didUploadPeople:self.peopleToSend];
        }
        NSString *response = [[NSString alloc] initWithData:self.peopleResponseData encoding:NSUTF8StringEncoding];
        NSInteger result = [response intValue];
        
        [self.peopleQueue removeObjectsInArray:self.peopleToSend];
        
        if (result == 0) {
            NSLog(@"sending people failed: %@", response);
        }
        
        [response release];
        [self archivePeople];
        self.peopleToSend = nil;
        self.peopleResponseData = nil;
        self.peopleConnection = nil;
    }
    
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(self.connection || self.peopleConnection)];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] && taskId != UIBackgroundTaskInvalid && self.connection == nil && self.peopleConnection == nil) {
		[[UIApplication sharedApplication] endBackgroundTask:taskId];
        taskId = UIBackgroundTaskInvalid;
	}
#endif
}

- (void)registerDeviceToken:(NSData*)deviceToken {
    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) return;
    NSMutableString *hex = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++)
        [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];

    [self addPersonToQueueWithAction:@"$union" andProperties:
        [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:[NSString stringWithString:hex]] forKey:@"$ios_devices"]
    ];
}

- (void)handlePush:(NSDictionary*)userInfo {
    NSString *message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)dealloc {
    [self archiveData];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [apiToken release], apiToken = nil;
    [eventQueue release], eventQueue = nil;
    [peopleQueue release], peopleQueue = nil;
    [superProperties release], superProperties = nil;
    [timer invalidate], [timer release], timer = nil;
    [eventsToSend release], eventsToSend = nil;
    [peopleToSend release], peopleToSend = nil;
    [responseData release], responseData = nil;
    [peopleResponseData release], peopleResponseData = nil;
    [connection release], connection = nil;
    [defaultUserId release], defaultUserId = nil;
    [super dealloc];
}
@end
