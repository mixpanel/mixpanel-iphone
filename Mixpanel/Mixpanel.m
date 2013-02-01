//
// Mixpanel.m
// Mixpanel
//
// Copyright 2012 Mixpanel
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if_dl.h>
#include <sys/sysctl.h>

#import <CommonCrypto/CommonHMAC.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "MPCJSONDataSerializer.h"
#import "Mixpanel.h"
#import "NSData+MPBase64.h"

#define VERSION @"1.1.0"

#ifndef IFT_ETHER
#define IFT_ETHER 0x6 // ethernet CSMACD
#endif

#ifdef MIXPANEL_LOG
#define MixpanelLog(...) NSLog(__VA_ARGS__)
#else
#define MixpanelLog(...)
#endif

#ifdef MIXPANEL_DEBUG
#define MixpanelDebug(...) NSLog(__VA_ARGS__)
#else
#define MixpanelDebug(...)
#endif

@interface Mixpanel ()

@property(nonatomic,readwrite,retain) MixpanelPeople *people; // re-declare internally as readwrite
@property(nonatomic,copy)   NSString *apiToken;
@property(nonatomic,retain) NSMutableDictionary *superProperties;
@property(nonatomic,retain) NSTimer *timer;
@property(nonatomic,retain) NSMutableArray *eventsQueue;
@property(nonatomic,retain) NSMutableArray *peopleQueue;
@property(nonatomic,retain) NSArray *eventsBatch;
@property(nonatomic,retain) NSArray *peopleBatch;
@property(nonatomic,retain) NSURLConnection *eventsConnection;
@property(nonatomic,retain) NSURLConnection *peopleConnection;
@property(nonatomic,retain) NSMutableData *eventsResponseData;
@property(nonatomic,retain) NSMutableData *peopleResponseData;

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
@property(nonatomic,assign) UIBackgroundTaskIdentifier taskId;
#endif

@end

@interface MixpanelPeople ()

@property(nonatomic,assign) Mixpanel *mixpanel;
@property(nonatomic,retain) NSMutableArray *unidentifiedQueue;

- (id)initWithMixpanel:(Mixpanel *)mixpanel;

@end

@implementation Mixpanel

static Mixpanel *sharedInstance = nil;

#pragma mark * Device info

+ (NSDictionary *)deviceInfoProperties
{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];

    UIDevice *device = [UIDevice currentDevice];

    [properties setValue:@"iphone" forKey:@"mp_lib"];
    [properties setValue:VERSION forKey:@"$lib_version"];

    [properties setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"$app_version"];

    [properties setValue:@"Apple" forKey:@"$manufacturer"];
    [properties setValue:[device systemName] forKey:@"$os"];
    [properties setValue:[device systemVersion] forKey:@"$os_version"];
    [properties setValue:[Mixpanel deviceModel] forKey:@"$model"];
    [properties setValue:[Mixpanel deviceModel] forKey:@"mp_device_model"]; // legacy

    CGSize size = [UIScreen mainScreen].bounds.size;
    [properties setValue:[NSNumber numberWithInt:(int)size.height] forKey:@"$screen_height"];
    [properties setValue:[NSNumber numberWithInt:(int)size.width] forKey:@"$screen_width"];

    [properties setValue:[NSNumber numberWithBool:[Mixpanel wifiAvailable]] forKey:@"$wifi"];

    CTTelephonyNetworkInfo *networkInfo = [[[CTTelephonyNetworkInfo alloc] init] autorelease];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];

    if (carrier.carrierName.length) {
        [properties setValue:carrier.carrierName forKey:@"$carrier"];
    }

    return [NSDictionary dictionaryWithDictionary:properties];
}

+ (NSString *)deviceModel
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

+ (BOOL)wifiAvailable
{
    struct sockaddr_in sockAddr;
    bzero(&sockAddr, sizeof(sockAddr));
    sockAddr.sin_len = sizeof(sockAddr);
    sockAddr.sin_family = AF_INET;

    SCNetworkReachabilityRef nrRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&sockAddr);
    SCNetworkReachabilityFlags flags;
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(nrRef, &flags);
    if (!didRetrieveFlags) {
        MixpanelDebug(@"%@ unable to fetch the network reachablity flags", self);
    }

    CFRelease(nrRef);

    if (!didRetrieveFlags || (flags & kSCNetworkReachabilityFlagsReachable) != kSCNetworkReachabilityFlagsReachable) {
        // unable to connect to a network (no signal or airplane mode activated)
        return NO;
    }

    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        // only a cellular network connection is available.
        return NO;
    }

    return YES;
}

+ (BOOL)inBackground
{
    BOOL inBg = NO;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    inBg = [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground;
#endif
    if (inBg) {
        MixpanelDebug(@"%@ in background", self);
    }
    return inBg;
}

+ (NSDictionary *)interfaces
{
    NSMutableDictionary *theDictionary = [NSMutableDictionary dictionary];
    
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    const struct sockaddr_dl * dlAddr;
    const uint8_t * base;
    
    success = getifaddrs(&addrs) == 0;
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            if ((cursor->ifa_addr->sa_family == AF_LINK) && (((const struct sockaddr_dl *)cursor->ifa_addr)->sdl_type == IFT_ETHER)) {
                // fprintf(stderr, "%s:", cursor->ifa_name);
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

+ (NSString *)uniqueDeviceString
{
    NSDictionary *dict = [Mixpanel interfaces];
    NSArray *keys = [dict allKeys];
    keys = [keys  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];

    // while most apps will define CFBundleName, it's not guaranteed;
    // an app can choose to define it or not so when it's missing, use the bundle file name
    if (bundleName == nil) {
        bundleName = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
    }
    
    NSMutableString *string = [NSMutableString stringWithString:bundleName];
    for (NSString *key in keys) {
        [string appendString:[dict objectForKey:key]];
    }
    return string;
}

#pragma mark * Encoding/decoding utilities

+ (NSString *)calculateHMACSHA1withString:(NSString *)str andKey:(NSString *)key
{
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

+ (NSData *)JSONSerializeObject:(id)obj
{
    id coercedObj = [Mixpanel JSONSerializableObjectForObject:obj];

    MPCJSONDataSerializer *serializer = [MPCJSONDataSerializer serializer];
    NSError *error = nil;
    NSData *data = nil;
    @try {
        data = [serializer serializeObject:coercedObj error:&error];
    }
    @catch (NSException *exception) {
        NSLog(@"%@ exception encoding api data: %@", self, exception);
    }
    if (error) {
        NSLog(@"%@ error encoding api data: %@", self, error);
    }
    return data;
}

+ (id)JSONSerializableObjectForObject:(id)obj
{
    // valid json types
    if ([obj isKindOfClass:[NSString class]] ||
        [obj isKindOfClass:[NSNumber class]] ||
        [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }

    // recurse on containers
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[Mixpanel JSONSerializableObjectForObject:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                NSLog(@"%@ warning: property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            } else {
                stringKey = [NSString stringWithString:key];
            }
            id v = [Mixpanel JSONSerializableObjectForObject:[obj objectForKey:key]];
            [d setObject:v forKey:stringKey];
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }

    // some common cases
    if ([obj isKindOfClass:[NSDate class]]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        NSString *s = [formatter stringFromDate:obj];
        [formatter release];
        return s;
    } else if ([obj isKindOfClass:[NSURL class]]) {
        return [obj absoluteString];
    }

    // default to sending the object's description
    NSString *s = [obj description];
    NSLog(@"%@ warning: property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

+ (NSString *)encodeAPIData:(NSArray *)array
{
    NSString *b64String = @"";
    NSData *data = [Mixpanel JSONSerializeObject:array];
    if (data) {
        b64String = [data mp_base64EncodedString];
        b64String = (id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                (CFStringRef)b64String,
                                                                NULL,
                                                                CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                kCFStringEncodingUTF8);
    }
    return [b64String autorelease];
}

+ (void)assertPropertyTypes:(NSDictionary *)properties
{
    for (id k in properties) {
        NSAssert([k isKindOfClass: [NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [k class], k);
        // would be convenient to do: id v = [properties objectForKey:k]; ..but, when the NSAssert's are stripped out in release, it becomes an unused variable error
        NSAssert([[properties objectForKey:k] isKindOfClass:[NSString class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSNumber class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSNull class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSArray class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSDictionary class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSDate class]] ||
                 [[properties objectForKey:k] isKindOfClass:[NSURL class]],
                 @"%@ property values must be NSString, NSNumber, NSNull, NSArray, NSDictionary, NSDate or NSURL. got: %@ %@", self, [[properties objectForKey:k] class], [properties objectForKey:k]);
    }
}

#pragma mark * Initializiation

+ (id)sharedInstanceWithToken:(NSString *)apiToken
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [[super alloc] initWithToken:apiToken andFlushInterval:60];
        }
        return sharedInstance;
    }
}

+ (id)sharedInstance
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            NSLog(@"%@ warning sharedInstance called before sharedInstanceWithToken:", self);
        }
        return sharedInstance;
    }
}

- (id)initWithToken:(NSString *)apiToken andFlushInterval:(NSUInteger)flushInterval
{
    if (apiToken == nil) {
        apiToken = @"";
    }
    if ([apiToken length] == 0) {
        NSLog(@"%@ warning empty api token", self);
    }
    if (self = [self init]) {
        self.people = [[[MixpanelPeople alloc] initWithMixpanel:self] autorelease];

        self.apiToken = apiToken;
        self.flushInterval = flushInterval;
        self.flushOnBackground = YES;
        self.showNetworkActivityIndicator = YES;
        self.serverURL = @"https://api.mixpanel.com";
        
        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];

        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        
        [self addApplicationObservers];
        
        [self unarchive];

    }
    return self;
}

#pragma mark * Tracking

- (NSString *)defaultDistinctId
{
    return [Mixpanel calculateHMACSHA1withString:[Mixpanel uniqueDeviceString] andKey:self.apiToken];
}

- (void)track:(NSString *)event
{
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    @synchronized(self) {
        if (event == nil || [event length] == 0) {
            NSLog(@"%@ mixpanel track called with empty event parameter. using 'mp_event'", self);
            event = @"mp_event";
        }
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        [p addEntriesFromDictionary:[Mixpanel deviceInfoProperties]];
        [p setObject:self.apiToken forKey:@"token"];
        [p setObject:[NSNumber numberWithLong:(long)[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
        if (self.nameTag) {
            [p setObject:self.nameTag forKey:@"mp_name_tag"];
        }
        if (self.distinctId) {
            [p setObject:self.distinctId forKey:@"distinct_id"];
        }
        [p addEntriesFromDictionary:self.superProperties];
        if (properties) {
            [p addEntriesFromDictionary:properties];
        }

        [Mixpanel assertPropertyTypes:properties];

        NSDictionary *e = [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", [NSDictionary dictionaryWithDictionary:p], @"properties", nil];
        MixpanelLog(@"%@ queueing event: %@", self, e);
        [self.eventsQueue addObject:e];
        if ([Mixpanel inBackground]) {
            [self archiveEvents];
        }
    }
}

#pragma mark * Super property methods

- (void)registerSuperProperties:(NSDictionary *)properties
{
    [Mixpanel assertPropertyTypes:properties];
    @synchronized(self) {
        [self.superProperties addEntriesFromDictionary:properties];
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    }
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties
{
    [Mixpanel assertPropertyTypes:properties];
    @synchronized(self) {
        for (NSString *key in properties) {
            if ([self.superProperties objectForKey:key] == nil) {
                [self.superProperties setObject:[properties objectForKey:key] forKey:key];
            }
        }
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    }
}

- (void)registerSuperPropertiesOnce:(NSDictionary *)properties defaultValue:(id)defaultValue
{
    [Mixpanel assertPropertyTypes:properties];
    @synchronized(self) {
        for (NSString *key in properties) {
            id value = [self.superProperties objectForKey:key];
            if (value == nil || [value isEqual:defaultValue]) {
                [self.superProperties setObject:[properties objectForKey:key] forKey:key];
            }
        }
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    }
}

- (void)clearSuperProperties
{
    @synchronized(self) {
        [self.superProperties removeAllObjects];
        if ([Mixpanel inBackground]) {
            [self archiveProperties];
        }
    }
}

- (NSDictionary *)currentSuperProperties
{
    @synchronized(self) {
        return [[self.superProperties copy] autorelease];
    }
}

- (void)reset
{
    @synchronized(self) {
        self.distinctId = [self defaultDistinctId];
        self.nameTag = nil;
        self.superProperties = [NSMutableDictionary dictionary];

        self.people.distinctId = nil;
        self.people.unidentifiedQueue = [NSMutableArray array];

        self.eventsQueue = [NSMutableArray array];
        self.peopleQueue = [NSMutableArray array];
        
        [self archive];
    }
}

#pragma mark * Network control

- (void)setFlushInterval:(NSUInteger)interval
{
    @synchronized(self) {
        _flushInterval = interval;
        [self startFlushTimer];
    }
}

- (void)startFlushTimer
{
    @synchronized(self) {
        [self stopFlushTimer];
        if (self.flushInterval > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            MixpanelDebug(@"%@ started flush timer: %@", self, self.timer);
        }
    }
}

- (void)stopFlushTimer
{
    @synchronized(self) {
        if (self.timer) {
            [self.timer invalidate];
            MixpanelDebug(@"%@ stopped flush timer: %@", self, self.timer);
        }
        self.timer = nil;
    }
}

- (void)flush
{
    @synchronized(self) {
        if ([self.delegate respondsToSelector:@selector(mixpanelWillFlush:)]) {
            if (![self.delegate mixpanelWillFlush:self]) {
                MixpanelDebug(@"%@ delegate deferred flush", self);
                return;
            }
        }
        MixpanelDebug(@"%@ flushing data to %@", self, self.serverURL);
        [self flushEvents];
        [self flushPeople];
    }
}

- (void)flushEvents
{
    if ([self.eventsQueue count] == 0) {
        MixpanelDebug(@"%@ no events to flush", self);
        return;
    } else if (self.eventsConnection != nil) {
        MixpanelDebug(@"%@ events connection already open", self);
        return;
    } else if ([self.eventsQueue count] > 50) {
        self.eventsBatch = [self.eventsQueue subarrayWithRange:NSMakeRange(0, 50)];
    } else {
        self.eventsBatch = [NSArray arrayWithArray:self.eventsQueue];
    }
    
    NSString *data = [Mixpanel encodeAPIData:self.eventsBatch];
    NSString *postBody = [NSString stringWithFormat:@"ip=1&data=%@", data];
    
    MixpanelDebug(@"%@ flushing %u of %u queued events: %@", self, self.eventsBatch.count, self.eventsQueue.count, self.eventsQueue);

    self.eventsConnection = [self apiConnectionWithEndpoint:@"/track/" andBody:postBody];

    [self updateNetworkActivityIndicator];
}

- (void)flushPeople
{
    if ([self.peopleQueue count] == 0) {
        MixpanelDebug(@"%@ no people to flush", self);
        return;
    } else if (self.peopleConnection != nil) {
        MixpanelDebug(@"%@ people connection already open", self);
        return;
    } else if ([self.peopleQueue count] > 50) {
        self.peopleBatch = [self.peopleQueue subarrayWithRange:NSMakeRange(0, 50)];
    } else {
        self.peopleBatch = [NSArray arrayWithArray:self.peopleQueue];
    }
    
    NSString *data = [Mixpanel encodeAPIData:self.peopleBatch];
    NSString *postBody = [NSString stringWithFormat:@"data=%@", data];
    
    MixpanelDebug(@"%@ flushing %u of %u queued people: %@", self, self.peopleBatch.count, self.peopleQueue.count, self.peopleQueue);

    self.peopleConnection = [self apiConnectionWithEndpoint:@"/engage/" andBody:postBody];

    [self updateNetworkActivityIndicator];
}

- (void)cancelFlush
{
    if (self.eventsConnection == nil) {
        MixpanelDebug(@"%@ no events connection to cancel", self);
    } else {
        MixpanelDebug(@"%@ cancelling events connection", self);
        [self.eventsConnection cancel];
        self.eventsConnection = nil;
    }
    if (self.peopleConnection == nil) {
        MixpanelDebug(@"%@ no people connection to cancel", self);
    } else {
        MixpanelDebug(@"%@ cancelling people connection", self);
        [self.peopleConnection cancel];
        self.peopleConnection = nil;
    }
}

- (void)updateNetworkActivityIndicator
{
    @synchronized(self) {
        BOOL visible = self.showNetworkActivityIndicator && (self.eventsConnection || self.peopleConnection);
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:visible];
    }
}

#pragma mark * Persistence

- (NSString *)filePathForData:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

- (NSString *)eventsFilePath
{
    return [self filePathForData:@"events"];
}

- (NSString *)peopleFilePath
{
    return [self filePathForData:@"people"];
}

- (NSString *)propertiesFilePath
{
    return [self filePathForData:@"properties"];
}

- (void)archive
{
    @synchronized(self) {
        [self archiveEvents];
        [self archivePeople];
        [self archiveProperties];
    }
}

- (void)archiveEvents
{
    @synchronized(self) {
        NSString *filePath = [self eventsFilePath];
        MixpanelDebug(@"%@ archiving events data to %@: %@", self, filePath, self.eventsQueue);
        if (![NSKeyedArchiver archiveRootObject:self.eventsQueue toFile:filePath]) {
            NSLog(@"%@ unable to archive events data", self);
        }
    }
}

- (void)archivePeople
{
    @synchronized(self) {
        NSString *filePath = [self peopleFilePath];
        MixpanelDebug(@"%@ archiving people data to %@: %@", self, filePath, self.peopleQueue);
        if (![NSKeyedArchiver archiveRootObject:self.peopleQueue toFile:filePath]) {
            NSLog(@"%@ unable to archive people data", self);
        }
    }
}

- (void)archiveProperties
{
    @synchronized(self) {
        NSString *filePath = [self propertiesFilePath];
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setValue:self.distinctId forKey:@"distinctId"];
        [properties setValue:self.nameTag forKey:@"nameTag"];
        [properties setValue:self.superProperties forKey:@"superProperties"];
        [properties setValue:self.people.distinctId forKey:@"peopleDistinctId"];
        [properties setValue:self.people.unidentifiedQueue forKey:@"peopleUnidentifiedQueue"];
        MixpanelDebug(@"%@ archiving properties data to %@: %@", self, filePath, properties);
        if (![NSKeyedArchiver archiveRootObject:properties toFile:filePath]) {
            NSLog(@"%@ unable to archive properties data", self);
        }
    }
}

- (void)unarchive
{
    @synchronized(self) {
        [self unarchiveEvents];
        [self unarchivePeople];
        [self unarchiveProperties];
    }
}

- (void)unarchiveEvents
{
    NSString *filePath = [self eventsFilePath];
    @try {
        self.eventsQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        MixpanelDebug(@"%@ unarchived events data: %@", self, self.eventsQueue);
    }
    @catch (NSException *exception) {
        NSLog(@"%@ unable to unarchive events data, starting fresh", self);
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        self.eventsQueue = nil;
    }
    if (!self.eventsQueue) {
        self.eventsQueue = [NSMutableArray array];
    }
}

- (void)unarchivePeople
{
    NSString *filePath = [self peopleFilePath];
    @try {
        self.peopleQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        MixpanelDebug(@"%@ unarchived people data: %@", self, self.peopleQueue);
    }
    @catch (NSException *exception) {
        NSLog(@"%@ unable to unarchive people data, starting fresh", self);
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        self.peopleQueue = nil;
    }
    if (!self.peopleQueue) {
        self.peopleQueue = [NSMutableArray array];
    }
}

- (void)unarchiveProperties
{
    NSString *filePath = [self propertiesFilePath];
    NSDictionary *properties = nil;
    @try {
        properties = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        MixpanelDebug(@"%@ unarchived properties data: %@", self, properties);
    }
    @catch (NSException *exception) {
        NSLog(@"%@ unable to unarchive properties data, starting fresh", self);
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    if (properties) {
        self.distinctId = [properties objectForKey:@"distinctId"];
        self.nameTag = [properties objectForKey:@"nameTag"];
        self.superProperties = [properties objectForKey:@"superProperties"];
        self.people.distinctId = [properties objectForKey:@"peopleDistinctId"];
        self.people.unidentifiedQueue = [properties objectForKey:@"peopleUnidentifiedQueue"];
    }
}

#pragma mark * Application lifecycle events

- (void)addApplicationObservers
{
    MixpanelDebug(@"%@ adding application observers", self);
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)] && &UIBackgroundTaskInvalid) {
        self.taskId = UIBackgroundTaskInvalid;
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
}

- (void)removeApplicationObservers
{
    MixpanelDebug(@"%@ removing application observers", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application did become active", self);
    @synchronized(self) {
        [self startFlushTimer];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application will resign active", self);
    @synchronized(self) {
        [self stopFlushTimer];
    }
}

- (void)applicationDidEnterBackground:(NSNotificationCenter *)notification
{
    MixpanelDebug(@"%@ did enter background", self);

    @synchronized(self) {

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
        if (self.flushOnBackground &&
            [[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)] &&
            [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)]) {

            self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                MixpanelDebug(@"%@ flush background task %u cut short", self, self.taskId);
                [self cancelFlush];
                [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
                self.taskId = UIBackgroundTaskInvalid;
            }];

            MixpanelDebug(@"%@ starting flush background task %u", self, self.taskId);
            [self flush];

            // connection callbacks end this task by calling endBackgroundTaskIfComplete
        }
#endif
    }
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification
{
    MixpanelDebug(@"%@ will enter foreground", self);
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    @synchronized(self) {

        if (&UIBackgroundTaskInvalid) {
            if (self.taskId != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            }
            self.taskId = UIBackgroundTaskInvalid;
        }
        [self cancelFlush];
        [self updateNetworkActivityIndicator];
    }
#endif
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    MixpanelDebug(@"%@ application will terminate", self);
    @synchronized(self) {
        [self archive];
    }
}

- (void)endBackgroundTaskIfComplete
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    // if the os version allows background tasks, the app supports them, and we're in one, end it
    @synchronized(self) {

        if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] &&
            self.taskId != UIBackgroundTaskInvalid && self.eventsConnection == nil && self.peopleConnection == nil) {
            MixpanelDebug(@"%@ ending flush background task %u", self, self.taskId);
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    }
#endif
}

#pragma mark * NSURLConnection callbacks

- (NSURLConnection *)apiConnectionWithEndpoint:(NSString *)endpoint andBody:(NSString *)body
{
    NSURL *url = [NSURL URLWithString:[self.serverURL stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    MixpanelDebug(@"%@ http request: %@?%@", self, [self.serverURL stringByAppendingString:endpoint], body);
    return [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    MixpanelDebug(@"%@ http status code: %d", self, [response statusCode]);
    if ([response statusCode] != 200) {
        NSLog(@"%@ http error: %@", self, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]);
    } else if (connection == self.eventsConnection) {
        self.eventsResponseData = [NSMutableData data];
    } else if (connection == self.peopleConnection) {
        self.peopleResponseData = [NSMutableData data];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection == self.eventsConnection) {
        [self.eventsResponseData appendData:data];
    } else if (connection == self.peopleConnection) {
        [self.peopleResponseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    @synchronized(self) {
        NSLog(@"%@ network failure: %@", self, error);
        if (connection == self.eventsConnection) {
            self.eventsBatch = nil;
            self.eventsResponseData = nil;
            self.eventsConnection = nil;
            [self archiveEvents];
        } else if (connection == self.peopleConnection) {
            self.peopleBatch = nil;
            self.peopleResponseData = nil;
            self.peopleConnection = nil;
            [self archivePeople];
        }

        [self updateNetworkActivityIndicator];
        
        [self endBackgroundTaskIfComplete];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    @synchronized(self) {
        MixpanelDebug(@"%@ http response finished loading", self);
        if (connection == self.eventsConnection) {
            NSString *response = [[NSString alloc] initWithData:self.eventsResponseData encoding:NSUTF8StringEncoding];
            if ([response intValue] == 0) {
                NSLog(@"%@ track api error: %@", self, response);
            }
            [response release];

            [self.eventsQueue removeObjectsInArray:self.eventsBatch];
            [self archiveEvents];

            self.eventsBatch = nil;
            self.eventsResponseData = nil;
            self.eventsConnection = nil;

        } else if (connection == self.peopleConnection) {
            NSString *response = [[NSString alloc] initWithData:self.peopleResponseData encoding:NSUTF8StringEncoding];
            if ([response intValue] == 0) {
                NSLog(@"%@ engage api error: %@", self, response);
            }
            [response release];

            [self.peopleQueue removeObjectsInArray:self.peopleBatch];
            [self archivePeople];

            self.peopleBatch = nil;
            self.peopleResponseData = nil;
            self.peopleConnection = nil;
        }
        
        [self updateNetworkActivityIndicator];
        
        [self endBackgroundTaskIfComplete];
    }
}

#pragma mark * NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Mixpanel: %p %@>", self, self.apiToken];
}

- (void)dealloc
{
    [self stopFlushTimer];
    [self removeApplicationObservers];
    
    self.people = nil;
    self.distinctId = nil;
    self.nameTag = nil;
    self.serverURL = nil;
    self.delegate = nil;
    
    self.apiToken = nil;
    self.superProperties = nil;
    self.timer = nil;
    self.eventsQueue = nil;
    self.peopleQueue = nil;
    self.eventsBatch = nil;
    self.peopleBatch = nil;
    self.eventsConnection = nil;
    self.peopleConnection = nil;
    self.eventsResponseData = nil;
    self.peopleResponseData = nil;
    
    [super dealloc];
}

@end

#pragma mark * People

@implementation MixpanelPeople

+ (NSDictionary *)deviceInfoProperties
{
    UIDevice *device = [UIDevice currentDevice];
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setValue:[Mixpanel deviceModel] forKey:@"$ios_device_model"];
    [properties setValue:[device systemVersion] forKey:@"$ios_version"];
    [properties setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"$ios_app_version"];
    return [NSDictionary dictionaryWithDictionary:properties];
}

- (id)initWithMixpanel:(Mixpanel *)mixpanel
{
    if (self = [self init]) {
        self.mixpanel = mixpanel;
        self.unidentifiedQueue = [NSMutableArray array];
    }
    return self;
}

- (void)identify:(NSString *)distinctId
{
    @synchronized(self) {
        [_distinctId autorelease];
        _distinctId = [distinctId copy];
        if (distinctId) {
            for (NSMutableDictionary *r in self.unidentifiedQueue) {
                [r setObject:distinctId forKey:@"$distinct_id"];
                [self.mixpanel.peopleQueue addObject:r];
            }
            [self.unidentifiedQueue removeAllObjects];
        }
        if ([Mixpanel inBackground]) {
            [self.mixpanel archiveProperties];
            [self.mixpanel archivePeople];
        }
    }
}

- (void)addPushDeviceToken:(NSData *)deviceToken
{
    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hex appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    NSArray *tokens = [NSArray arrayWithObject:[NSString stringWithString:hex]];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:tokens forKey:@"$ios_devices"];
    [self addPeopleRecordToQueueWithAction:@"$union" andProperties:properties];
}

- (void)set:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$set" andProperties:properties];
}

- (void)set:(NSString *)property to:(id)object
{
    NSAssert(property != nil, @"property must not be nil");
    NSAssert(object != nil, @"object must not be nil");
    if (property == nil || object == nil) {
        return;
    }
    [self set:[NSDictionary dictionaryWithObject:object forKey:property]];
}

- (void)increment:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    for (id v in [properties allValues]) {
        NSAssert([v isKindOfClass:[NSNumber class]],
                 @"%@ increment property values should be NSNumber. found: %@", self, v);
    }
    [self addPeopleRecordToQueueWithAction:@"$add" andProperties:properties];
}

- (void)increment:(NSString *)property by:(NSNumber *)amount
{
    NSAssert(property != nil, @"property must not be nil");
    NSAssert(amount != nil, @"amount must not be nil");
    if (property == nil || amount == nil) {
        return;
    }
    [self increment:[NSDictionary dictionaryWithObject:amount forKey:property]];
}

- (void)append:(NSDictionary *)properties
{
    NSAssert(properties != nil, @"properties must not be nil");
    [Mixpanel assertPropertyTypes:properties];
    [self addPeopleRecordToQueueWithAction:@"$append" andProperties:properties];
}

- (void)trackCharge:(NSNumber *)amount
{
    [self trackCharge:amount withProperties:nil];
}

- (void)trackCharge:(NSNumber *)amount withProperties:(NSDictionary *)properties
{
    NSAssert(amount != nil, @"amount must not be nil");
    if (amount != nil) {
        NSMutableDictionary *txn = [NSMutableDictionary dictionaryWithObjectsAndKeys:amount, @"$amount", [NSDate date], @"$time", nil];
        if (properties) {
            [txn addEntriesFromDictionary:properties];
        }
        [self append:[NSDictionary dictionaryWithObject:txn forKey:@"$transactions"]];
    }
}

- (void)clearCharges
{
    [self set:[NSDictionary dictionaryWithObject:[NSArray array] forKey:@"$transactions"]];
}

- (void)deleteUser
{
    [self addPeopleRecordToQueueWithAction:@"$delete" andProperties:[NSDictionary dictionary]];
}

- (void)addPeopleRecordToQueueWithAction:(NSString *)action andProperties:(NSDictionary *)properties
{
    @synchronized(self) {

        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        NSMutableDictionary *p = [NSMutableDictionary dictionary];

        [r setObject:self.mixpanel.apiToken forKey:@"$token"];

        if (![r objectForKey:@"$time"]) {
            // milliseconds unix timestamp
            NSNumber *time = [NSNumber numberWithUnsignedLongLong:(uint64_t)([[NSDate date] timeIntervalSince1970] * 1000)];
            [r setObject:time forKey:@"$time"];
        }

        if ([action isEqualToString:@"$set"]) {
            [p addEntriesFromDictionary:[MixpanelPeople deviceInfoProperties]];
        }

        [p addEntriesFromDictionary:properties];

        [r setObject:[NSDictionary dictionaryWithDictionary:p] forKey:action];

        if (self.distinctId) {
            [r setObject:self.distinctId forKey:@"$distinct_id"];
            MixpanelLog(@"%@ queueing people record: %@", self.mixpanel, r);
            [self.mixpanel.peopleQueue addObject:r];
        } else {
            MixpanelLog(@"%@ queueing unidentified people record: %@", self.mixpanel, r);
            [self.unidentifiedQueue addObject:r];
        }
        if ([Mixpanel inBackground]) {
            [self.mixpanel archivePeople];
        }
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MixpanelPeople: %p %@>", self, self.mixpanel.apiToken];
}

- (void)dealloc
{
    self.mixpanel = nil;
    self.distinctId = nil;
    self.unidentifiedQueue = nil;
    [super dealloc];
}

@end
