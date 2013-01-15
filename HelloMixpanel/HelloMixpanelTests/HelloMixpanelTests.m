//
//  HelloMixpanelTests.m
//  HelloMixpanelTests
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

#import "HelloMixpanelTests.h"

#import "Mixpanel.h"
#import "MPCJSONSerializer.h"

#define TEST_TOKEN @"abc123"

@interface Mixpanel (Test)

// get access to private members
@property(nonatomic,retain) NSMutableArray *eventsQueue;
@property(nonatomic,retain) NSMutableArray *peopleQueue;
@property(nonatomic,retain) NSTimer *timer;

+ (NSData *)JSONSerializeObject:(id)obj;
- (NSString *)defaultDistinctId;
- (void)archive;
- (NSString *)eventsFilePath;
- (NSString *)peopleFilePath;
- (NSString *)propertiesFilePath;

@end

@interface MixpanelPeople (Test)

// get access to private members
@property(nonatomic,retain) NSMutableArray *unidentifiedQueue;

@end

@interface HelloMixpanelTests ()  <MixpanelDelegate>

@property(nonatomic,retain) Mixpanel *mixpanel;

@end

@implementation HelloMixpanelTests

- (void)setUp
{
    [super setUp];
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];
    [self.mixpanel reset];
}

- (void)tearDown
{
    [super tearDown];
    self.mixpanel = nil;
}

- (BOOL)mixpanelWillFlush:(Mixpanel *)mixpanel
{
    return NO;
}

- (NSDictionary *)allPropertyTypes
{
    NSNumber *number = [NSNumber numberWithInt:3];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    NSDate *date = [dateFormatter dateFromString:@"2012-09-28 19:14:36 PDT"];
    [dateFormatter release];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:@"v" forKey:@"k"];
    NSArray *array = [NSArray arrayWithObject:@"1"];
    NSNull *null = [NSNull null];

    NSDictionary *nested = [NSDictionary dictionaryWithObject:
                            [NSDictionary dictionaryWithObject:
                             [NSArray arrayWithObject:
                              [NSDictionary dictionaryWithObject:
                               [NSArray arrayWithObject:@"bottom"]
                                                          forKey:@"p3"]]
                                                        forKey:@"p2"]
                                                       forKey:@"p1"];
    NSURL *url = [NSURL URLWithString:@"https://mixpanel.com/"];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"yello",   @"string",
            number,     @"number",
            date,       @"date",
            dictionary, @"dictionary",
            array,      @"array",
            null,       @"null",
            nested,     @"nested",
            url,        @"url",
            @1.3,       @"float",
            nil];
}

- (void)testJSONSerializeObject {
    NSDictionary *test = [self allPropertyTypes];
    NSData *data = [Mixpanel JSONSerializeObject:[NSArray arrayWithObject:test]];
    NSString *json = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(json, @"[{\"float\":1.3,\"string\":\"yello\",\"url\":\"https:\\/\\/mixpanel.com\\/\",\"nested\":{\"p1\":{\"p2\":[{\"p3\":[\"bottom\"]}]}},\"array\":[\"1\"],\"date\":\"2012-09-29T02:14:36\",\"dictionary\":{\"k\":\"v\"},\"null\":null,\"number\":3}]", @"json serialization failed");

    test = [NSDictionary dictionaryWithObject:@"non-string key" forKey:@3];
    data = [Mixpanel JSONSerializeObject:[NSArray arrayWithObject:test]];
    json = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(json, @"[{\"3\":\"non-string key\"}]", @"json serialization failed");
}

- (void)testIdentify
{
    NSString *distinctId = @"d1";
    STAssertFalse([self.mixpanel.distinctId isEqualToString:distinctId], @"incorrect default distinct id: %@", distinctId);
    [self.mixpanel identify:distinctId];
    STAssertEqualObjects(self.mixpanel.distinctId, distinctId, @"mixpanel identify failed to set distinct id");
    [self.mixpanel track:@"e1"];
    NSString *trackDistinctId = [[self.mixpanel.eventsQueue.lastObject objectForKey:@"properties"] objectForKey:@"distinct_id"];
    STAssertEqualObjects(trackDistinctId, distinctId, @"user-defined distinct id not used in track. got: %@", trackDistinctId);
}

- (void)testTrack
{
    [self.mixpanel track:@"Something Happened"];
    STAssertTrue(self.mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    STAssertEquals([e objectForKey:@"event"], @"Something Happened", @"incorrect event name");
    NSDictionary *p = [e objectForKey:@"properties"];
    STAssertTrue(p.count == 14, @"incorrect number of properties");

    STAssertNotNil([p objectForKey:@"$app_version"], @"$app_version not set");
    STAssertNotNil([p objectForKey:@"$lib_version"], @"$lib_version not set");
    STAssertEqualObjects([p objectForKey:@"$manufacturer"], @"Apple", @"incorrect $manufacturer");
    STAssertNotNil([p objectForKey:@"$model"], @"$model not set");
    STAssertNotNil([p objectForKey:@"$os"], @"$os not set");
    STAssertNotNil([p objectForKey:@"$os_version"], @"$os_version not set");
    STAssertNotNil([p objectForKey:@"$screen_height"], @"$screen_height not set");
    STAssertNotNil([p objectForKey:@"$screen_width"], @"$screen_width not set");
    STAssertNotNil([p objectForKey:@"distinct_id"], @"distinct_id not set");
    STAssertNotNil([p objectForKey:@"mp_device_model"], @"mp_device_model not set");
    STAssertEqualObjects([p objectForKey:@"mp_lib"], @"iphone", @"incorrect mp_lib");
    STAssertNotNil([p objectForKey:@"time"], @"time not set");
    STAssertEqualObjects([p objectForKey:@"token"], TEST_TOKEN, @"incorrect token");
}

- (void)testTrackProperties
{
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"yello",                   @"string",
                       [NSNumber numberWithInt:3], @"number",
                       [NSDate date],              @"date",
                       @"override",                @"$app_version",
                       nil];
    [self.mixpanel track:@"Something Happened" properties:p];
    STAssertTrue(self.mixpanel.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.mixpanel.eventsQueue.lastObject;
    STAssertEquals([e objectForKey:@"event"], @"Something Happened", @"incorrect event name");
    p = [e objectForKey:@"properties"];
    STAssertTrue(p.count == 17, @"incorrect number of properties");
    STAssertEqualObjects([p objectForKey:@"$app_version"], @"override", @"reserved property override failed");
}

- (void)testTrackWithCustomDistinctIdAndToken
{
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"t1",                      @"token",
                       @"d1",                      @"distinct_id",
                       nil];
    [self.mixpanel track:@"e1" properties:p];
    NSString *trackToken = [[self.mixpanel.eventsQueue.lastObject objectForKey:@"properties"] objectForKey:@"token"];
    NSString *trackDistinctId = [[self.mixpanel.eventsQueue.lastObject objectForKey:@"properties"] objectForKey:@"distinct_id"];
    STAssertEqualObjects(trackToken, @"t1", @"user-defined distinct id not used in track. got: %@", trackToken);
    STAssertEqualObjects(trackDistinctId, @"d1", @"user-defined distinct id not used in track. got: %@", trackDistinctId);
}

- (void)testSuperProperties
{
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"a",                       @"p1",
                       [NSNumber numberWithInt:3], @"p2",
                       [NSDate date],              @"p2",
                       nil];

    [self.mixpanel registerSuperProperties:p];
    STAssertEqualObjects([self.mixpanel currentSuperProperties], p, @"register super properties failed");
    p = [NSDictionary dictionaryWithObject:@"b" forKey:@"p1"];
    [self.mixpanel registerSuperProperties:p];
    STAssertEqualObjects([[self.mixpanel currentSuperProperties] objectForKey:@"p1"], @"b",
                         @"register super properties failed to overwrite existing value");

    p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p4"];
    [self.mixpanel registerSuperPropertiesOnce:p];
    STAssertEqualObjects([[self.mixpanel currentSuperProperties] objectForKey:@"p4"], @"a",
                         @"register super properties once failed first time");
    p = [NSDictionary dictionaryWithObject:@"b" forKey:@"p4"];
    [self.mixpanel registerSuperPropertiesOnce:p];
    STAssertEqualObjects([[self.mixpanel currentSuperProperties] objectForKey:@"p4"], @"a",
                         @"register super properties once failed second time");

    p = [NSDictionary dictionaryWithObject:@"c" forKey:@"p4"];
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"d"];
    STAssertEqualObjects([[self.mixpanel currentSuperProperties] objectForKey:@"p4"], @"a",
                         @"register super properties once with default value failed when no match");
    [self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"a"];
    STAssertEqualObjects([[self.mixpanel currentSuperProperties] objectForKey:@"p4"], @"c",
                         @"register super properties once with default value failed when match");
    [self.mixpanel clearSuperProperties];
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"clear super properties failed");
}

- (void)testAssertPropertyTypes
{
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSData data] forKey:@"data"];
    STAssertThrows([self.mixpanel track:@"e1" properties:p], @"property type should not be allowed");
    STAssertThrows([self.mixpanel registerSuperProperties:p], @"property type should not be allowed");
    STAssertThrows([self.mixpanel registerSuperPropertiesOnce:p], @"property type should not be allowed");
    STAssertThrows([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"], @"property type should not be allowed");
    p = [self allPropertyTypes];
    STAssertNoThrow([self.mixpanel track:@"e1" properties:p], @"property type should be allowed");
    STAssertNoThrow([self.mixpanel registerSuperProperties:p], @"property type should be allowed");
    STAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p],  @"property type should be allowed");
    STAssertNoThrow([self.mixpanel registerSuperPropertiesOnce:p defaultValue:@"v"],  @"property type should be allowed");
}

- (void)testReset
{
    NSDictionary *p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p1"];
    [self.mixpanel identify:@"d1"];
    self.mixpanel.nameTag = @"n1";
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people set:p];
    [self.mixpanel archive];

    [self.mixpanel reset];
    STAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset");
    STAssertNil(self.mixpanel.nameTag, @"name tag failed to reset");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"super properties failed to reset");
    STAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset");
    STAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset");
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset");
    
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];
    STAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"distinct id failed to reset after archive");
    STAssertNil(self.mixpanel.nameTag, @"name tag failed to reset after archive");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"super properties failed to reset after archive");
    STAssertTrue(self.mixpanel.eventsQueue.count == 0, @"events queue failed to reset after archive");
    STAssertNil(self.mixpanel.people.distinctId, @"people distinct id failed to reset after archive");
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people queue failed to reset after archive");
}

- (void)testFlushTimer
{
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];
    STAssertNil(self.mixpanel.timer, @"intializing with a flush interval of 0 still started timer");
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:60] autorelease];
    STAssertNotNil(self.mixpanel.timer, @"intializing with a flush interval of 60 did not start timer");
}

- (void)testArchive
{
    [self.mixpanel archive];
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];

    STAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id archive failed");
    STAssertNil(self.mixpanel.nameTag, @"default name tag archive failed");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties archive failed");
    STAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue archive failed");
    STAssertNil(self.mixpanel.people.distinctId, @"default people distinct id archive failed");
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue archive failed");

    NSDictionary *p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p1"];
    [self.mixpanel identify:@"d1"];
    self.mixpanel.nameTag = @"n1";
    [self.mixpanel registerSuperProperties:p];
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people set:p];

    [self.mixpanel archive];
    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];

    STAssertEqualObjects(self.mixpanel.distinctId, @"d1", @"custom distinct archive failed");
    STAssertEqualObjects(self.mixpanel.nameTag, @"n1", @"custom name tag archive failed");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 1, @"custom super properties archive failed");
    STAssertTrue(self.mixpanel.eventsQueue.count == 1, @"pending events queue archive failed");
    STAssertEqualObjects(self.mixpanel.people.distinctId, @"d1", @"custom people distinct id archive failed");
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"pending people queue archive failed");

    NSFileManager *fileManager = [NSFileManager defaultManager];

    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"events archive file not found");
    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"people archive file not found");
    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"properties archive file not found");

    // no existing file

    [fileManager removeItemAtPath:[self.mixpanel eventsFilePath] error:NULL];
    [fileManager removeItemAtPath:[self.mixpanel peopleFilePath] error:NULL];
    [fileManager removeItemAtPath:[self.mixpanel propertiesFilePath] error:NULL];

    STAssertFalse([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"events archive file not removed");
    STAssertFalse([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"people archive file not removed");
    STAssertFalse([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"properties archive file not removed");

    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];
    STAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id from no file failed");
    STAssertNil(self.mixpanel.nameTag, @"default name tag archive from no file failed");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties from no file failed");
    STAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from no file is nil");
    STAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue from no file not empty");
    STAssertNil(self.mixpanel.people.distinctId, @"default people distinct id from no file failed");
    STAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from no file is nil");
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue from no file not empty");

    // corrupt file

    NSData *garbage = [@"garbage" dataUsingEncoding:NSUTF8StringEncoding];
    [garbage writeToFile:[self.mixpanel eventsFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel peopleFilePath] atomically:NO];
    [garbage writeToFile:[self.mixpanel propertiesFilePath] atomically:NO];

    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel eventsFilePath]], @"garbage events archive file not found");
    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel peopleFilePath]], @"garbage people archive file not found");
    STAssertTrue([fileManager fileExistsAtPath:[self.mixpanel propertiesFilePath]], @"garbage properties archive file not found");

    self.mixpanel = [[[Mixpanel alloc] initWithToken:TEST_TOKEN andFlushInterval:0] autorelease];
    STAssertEqualObjects(self.mixpanel.distinctId, [self.mixpanel defaultDistinctId], @"default distinct id from garbage failed");
    STAssertNil(self.mixpanel.nameTag, @"default name tag archive from garbage failed");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"default super properties from garbage failed");
    STAssertNotNil(self.mixpanel.eventsQueue, @"default events queue from garbage is nil");
    STAssertTrue(self.mixpanel.eventsQueue.count == 0, @"default events queue from garbage not empty");
    STAssertNil(self.mixpanel.people.distinctId, @"default people distinct id from garbage failed");
    STAssertNotNil(self.mixpanel.peopleQueue, @"default people queue from garbage is nil");
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"default people queue from garbage not empty");
}

- (void)testPeopleIdentify
{
    NSDictionary *p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p1"];
    [self.mixpanel.people set:p];
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, @"people records should go to unidentified queue before identify");
    STAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 1, @"unidentified people records not queued");
    NSDictionary *r = self.mixpanel.people.unidentifiedQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"incorrect project token in people record");
    p = [r objectForKey:@"$set"];
    STAssertTrue(p.count == 4, @"incorrect people properties: %@", p);
    STAssertEqualObjects([p objectForKey:@"p1"], @"a", @"custom people property not queued");
    STAssertNotNil([p objectForKey:@"$ios_device_model"], @"missing $ios_device_model property");
    STAssertNotNil([p objectForKey:@"$ios_version"], @"missing $ios_version property");
    STAssertNotNil([p objectForKey:@"$ios_app_version"], @"missing $ios_app_version property");
    [self.mixpanel.people identify:@"d1"];
    STAssertEqualObjects(self.mixpanel.people.distinctId, @"d1", @"set people distinct id failed");
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"identify should move unidentified records to main queue");
    STAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0, @"identify should move records from unidentified queue");
}

- (void)testPeopleAddPushDeviceToken
{
    [self.mixpanel.people identify:@"d1"];
    NSData *token = [@"0123456789abcdef" dataUsingEncoding:[NSString defaultCStringEncoding]];
    [self.mixpanel.people addPushDeviceToken:token];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$union"], @"$union dictionary missing");
    NSDictionary *p = [r objectForKey:@"$union"];
    STAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    NSArray *a = [p objectForKey:@"$ios_devices"];
    STAssertTrue(a.count == 1, @"device token array not set");
    STAssertEqualObjects(a.lastObject, @"30313233343536373839616263646566", @"device token not encoded properly");
}

- (void)testPeopleSet
{
    [self.mixpanel.people identify:@"d1"];
    NSDictionary *p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p1"];
    [self.mixpanel.people set:p];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$set"], @"$set dictionary missing");
    p = [r objectForKey:@"$set"];
    STAssertTrue(p.count == 4, @"incorrect people properties: %@", p);
    STAssertEqualObjects([p objectForKey:@"p1"], @"a", @"custom people property not queued");
    STAssertNotNil([p objectForKey:@"$ios_device_model"], @"missing $ios_device_model property");
    STAssertNotNil([p objectForKey:@"$ios_version"], @"missing $ios_version property");
    STAssertNotNil([p objectForKey:@"$ios_app_version"], @"missing $ios_app_version property");
}

- (void)testPeopleSetReservedProperty
{
    [self.mixpanel.people identify:@"d1"];
    NSDictionary *p = [NSDictionary dictionaryWithObject:@"override" forKey:@"$ios_app_version"];
    [self.mixpanel.people set:p];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    p = [r objectForKey:@"$set"];
    STAssertEqualObjects([p objectForKey:@"$ios_app_version"], @"override", @"reserved property override failed");
}

- (void)testPeopleSetTo
{
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$set"], @"$set dictionary missing");
    NSDictionary *p = [r objectForKey:@"$set"];
    STAssertTrue(p.count == 4, @"incorrect people properties: %@", p);
    STAssertEqualObjects([p objectForKey:@"p1"], @"a", @"custom people property not queued");
    STAssertNotNil([p objectForKey:@"$ios_device_model"], @"missing $ios_device_model property");
    STAssertNotNil([p objectForKey:@"$ios_version"], @"missing $ios_version property");
    STAssertNotNil([p objectForKey:@"$ios_app_version"], @"missing $ios_app_version property");
}

- (void)testPeopleIncrement
{
    [self.mixpanel.people identify:@"d1"];
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:3] forKey:@"p1"];
    [self.mixpanel.people increment:p];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$add"], @"$add dictionary missing");
    p = [r objectForKey:@"$add"];
    STAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    STAssertEqualObjects([p objectForKey:@"p1"], [NSNumber numberWithInt:3], @"custom people property not queued");
}

- (void)testPeopleIncrementBy
{
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people increment:@"p1" by:[NSNumber numberWithInt:3]];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$add"], @"$add dictionary missing");
    NSDictionary *p = [r objectForKey:@"$add"];
    STAssertTrue(p.count == 1, @"incorrect people properties: %@", p);
    STAssertEqualObjects([p objectForKey:@"p1"], [NSNumber numberWithInt:3], @"custom people property not queued");
}

- (void)testPeopleDeleteUser
{
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people deleteUser];
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"people records not queued");
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects([r objectForKey:@"$token"], TEST_TOKEN, @"project token not set");
    STAssertEqualObjects([r objectForKey:@"$distinct_id"], @"d1", @"distinct id not set");
    STAssertNotNil([r objectForKey:@"$delete"], @"$delete dictionary missing");
    NSDictionary *p = [r objectForKey:@"$delete"];
    STAssertTrue(p.count == 0, @"incorrect people properties: %@", p);
}

- (void)testMixpanelDelegate
{
    self.mixpanel.delegate = self;
    [self.mixpanel track:@"e1"];
    [self.mixpanel.people identify:@"d1"];
    [self.mixpanel.people set:@"p1" to:@"a"];
    [self.mixpanel flush];
    STAssertTrue(self.mixpanel.eventsQueue.count == 1, @"delegate should have stopped flush");
    STAssertTrue(self.mixpanel.peopleQueue.count == 1, @"delegate should have stopped flush");
}

- (void)testPeopleAssertPropertyTypes
{
    NSURL *d = [NSData data];
    NSDictionary *p = [NSDictionary dictionaryWithObject:d forKey:@"URL"];
    STAssertThrows([self.mixpanel.people set:p], @"unsupported property allowed");
    STAssertThrows([self.mixpanel.people set:@"p1" to:d], @"unsupported property allowed");
    p = [NSDictionary dictionaryWithObject:@"a" forKey:@"p1"]; // increment should require a number
    STAssertThrows([self.mixpanel.people increment:p], @"unsupported property allowed");
}

- (void)testNilArguments
{
    [self.mixpanel identify:nil];
    STAssertNil(self.mixpanel.people.distinctId, @"identify nil should make distinct id nil");
    [self.mixpanel track:nil];
    [self.mixpanel track:nil properties:nil];
    [self.mixpanel registerSuperProperties:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil];
    [self.mixpanel registerSuperPropertiesOnce:nil defaultValue:nil];

    // legacy behavior
    STAssertTrue(self.mixpanel.eventsQueue.count == 2, @"track with nil should create mp_event event");
    STAssertEqualObjects([self.mixpanel.eventsQueue.lastObject objectForKey:@"event"], @"mp_event", @"track with nil should create mp_event event");
    STAssertNotNil([self.mixpanel currentSuperProperties], @"setting super properties to nil should have no effect");
    STAssertTrue([[self.mixpanel currentSuperProperties] count] == 0, @"setting super properties to nil should have no effect");

    [self.mixpanel.people identify:nil];
    STAssertNil(self.mixpanel.people.distinctId, @"people identify nil should make people distinct id nil");
    STAssertThrows([self.mixpanel.people set:nil], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people set:nil to:@"a"], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people set:@"p1" to:nil], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people set:nil to:nil], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people increment:nil], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people increment:nil by:[NSNumber numberWithInt:3]], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people increment:@"p1" by:nil], @"should not take nil argument");
    STAssertThrows([self.mixpanel.people increment:nil by:nil], @"should not take nil argument");
}

- (void)testPeopleTrackCharge
{
    [self.mixpanel.people identify:@"d1"];

    [self.mixpanel.people trackCharge:@25];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25, nil);
    STAssertNotNil(r[@"$append"][@"$transactions"][@"$time"], nil);
    [self.mixpanel.peopleQueue removeAllObjects];

    [self.mixpanel.people trackCharge:@25.34];
    r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25.34, nil);
    STAssertNotNil(r[@"$append"][@"$transactions"][@"$time"], nil);
    [self.mixpanel.peopleQueue removeAllObjects];

    // require a number
    STAssertThrows([self.mixpanel.people trackCharge:nil], nil);
    STAssertTrue(self.mixpanel.peopleQueue.count == 0, nil);

    // but allow 0
    [self.mixpanel.people trackCharge:@0];
    r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @0, nil);
    STAssertNotNil(r[@"$append"][@"$transactions"][@"$time"], nil);
    [self.mixpanel.peopleQueue removeAllObjects];

    // allow $time override
    NSDictionary *p = [self allPropertyTypes];
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"$time": p[@"date"]}];
    r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25, nil);
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$time"], p[@"date"], nil);
    [self.mixpanel.peopleQueue removeAllObjects];

    // allow arbitrary charge properties
    [self.mixpanel.people trackCharge:@25 withProperties:@{@"p1": @"a"}];
    r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"$amount"], @25, nil);
    STAssertEqualObjects(r[@"$append"][@"$transactions"][@"p1"], @"a", nil);
}

- (void)testPeopleClearCharges
{
    [self.mixpanel.people identify:@"d1"];

    [self.mixpanel.people clearCharges];
    NSDictionary *r = self.mixpanel.peopleQueue.lastObject;
    STAssertEqualObjects(r[@"$set"][@"$transactions"], @[], nil);
}

@end
