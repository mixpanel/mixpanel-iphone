//
//  Unit_Tests.m
//  Unit Tests
//

#import "Unit_Tests.h"

int connection_count = 0;

@interface MixpanelAPI (UnitTests)
- (NSURLConnection*)apiConnectionWithEndpoint:(NSString*)endpoint andBody:(NSString*)body;
@end

@implementation MixpanelAPI (UnitTests)
- (NSURLConnection*)apiConnectionWithEndpoint:(NSString*)endpoint andBody:(NSString*)body {
    NSURL *url = [NSURL URLWithString:@"http://localhost/"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    connection_count++;
    
    return [NSURLConnection connectionWithRequest:request delegate:self];
}
@end

@implementation Unit_Tests

- (void)setUp {
    [super setUp];
    
    mp = [[MixpanelAPI alloc] initWithToken:MP_TEST_TOKEN];
    [mp setUploadInterval:MP_TEST_UPLOAD_INTERVAL];
    
    // Over-ride any archived data
    mp.peopleQueue = [NSMutableArray array];
    mp.eventQueue = [NSMutableArray array];
}

- (void)tearDown {
    [super tearDown];
    
    [mp stop];
    [mp release];
}

- (void)testFlush {    
    [mp track:@"Event"];
    [mp setUserProperty:@"John" forKey:@"name"];
    
    STAssertTrue([mp.eventQueue count] == 1, @"track: failed, not in queue");
    STAssertTrue([mp.peopleQueue count] == 1, @"setProperty:forKey: failed, not in queue");
    
    connection_count = 0;
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:MP_TEST_UPLOAD_INTERVAL+1]]; // wait a while
        
    STAssertTrue(connection_count == 2, @"Connections not created %d");
}

- (void)testMultipleSet {
    [mp setUserProperty:@"1" forKey:@"1"];
    [mp setUserProperty:@"2" forKey:@"2"];
    [mp incrementUserPropertyWithKey:@"3"];
    [mp setUserProperties:[NSDictionary dictionaryWithObject:@"4" forKey:@"4"]];
    [mp append:@"5" toUserPropertyWithKey:@"5"];
    
    STAssertTrue(mp.peopleQueue.count == 5, @"Not all sets recorded");
}

- (void)testArchive {
    [mp track:@"Event"];
    [mp setUserProperty:@"John" forKey:@"name"];
    
    [mp archiveData];
    
    mp.peopleQueue = nil;
    mp.eventQueue = nil;
    
    [mp unarchiveData];
    
    STAssertTrue([mp.eventQueue count] == 1, @"Archive/unarchive of event failed");
    STAssertTrue([mp.peopleQueue count] == 1, @"Archive/unarchive of people failed");
}

- (void)testTrackFormat {    
    NSString *eventName = @"Test Event";
    NSString *property_key = @"Test Property";
    NSNumber *property_value = [NSNumber numberWithInt:2];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:property_value forKey:property_key];
    
    [mp track:eventName properties:properties];
    
    NSDictionary *event = [[mp.eventQueue objectAtIndex:0] valueForKey:@"dictionaryValue"];
    STAssertEquals([event objectForKey:@"event"], eventName, @"track:properties: event is not set properly.");
    STAssertEquals([[event objectForKey:@"properties"] objectForKey:property_key], property_value, @"track:properties: event properties are not set properly.");
}

- (void)testSetPropertyFormat {    
    NSString *value = @"John Smith";
    NSString *key = @"name";
    
    [mp setUserProperty:value forKey:key];
        
    STAssertTrue([mp.peopleQueue count] == 1, @"setProperty:forKey: failed. Set not in queue.");
    
    NSDictionary *person = [mp.peopleQueue objectAtIndex:0];
    
    STAssertNotNil([person objectForKey:@"$distinct_id"], @"$distinct_id does not exist.");
    STAssertNotNil([person objectForKey:@"$time"], @"$time does not exist.");
    STAssertNotNil([person objectForKey:@"$token"], @"$token does not exist.");
    STAssertNotNil([person objectForKey:@"$set"], @"$set does not exist.");
    STAssertEquals([[person objectForKey:@"$set"] objectForKey:key], value, @"property not set properly");
}

- (void)testIncrementPropertyFormat {
    NSString *key = @"numeric";
    
    [mp incrementUserPropertyWithKey:key];
    [mp incrementUserPropertyWithKey:key byInt:2];
    [mp incrementUserPropertyWithKey:key byNumber:[NSNumber numberWithInt:3]];
    [mp incrementUserProperties:[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:4], key, nil]];
    
    STAssertEquals([NSNumber numberWithInt:1], [[[mp.peopleQueue objectAtIndex:0] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey: failed.");
    STAssertEquals([NSNumber numberWithInt:2], [[[mp.peopleQueue objectAtIndex:1] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey:byInt: failed.");
    STAssertEquals([NSNumber numberWithInt:3], [[[mp.peopleQueue objectAtIndex:2] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey:byNumber: failed.");
    STAssertEquals([NSNumber numberWithInt:4], [[[mp.peopleQueue objectAtIndex:3] objectForKey:@"$add"] objectForKey:key], @"incrementProperties: failed.");
}

- (void)testAppendPropertyFormat {    
    NSString *key = @"property_key";
    NSString *value = @"to_append";
    
    [mp append:value toUserPropertyWithKey:key];
    
    STAssertEquals(value, [[[mp.peopleQueue objectAtIndex:0] objectForKey:@"$append"] objectForKey:key], @"append:toPropertyWithKey: failed.");
}

- (void)testDeleteUserFormat {
    NSString *distinct_id = @"user1";
    
    [mp deleteUser:distinct_id];
    [mp deleteCurrentUser];
    [mp identifyUser:distinct_id];
    [mp deleteCurrentUser];
    
    STAssertEquals(distinct_id, [[mp.peopleQueue objectAtIndex:0] objectForKey:@"$distinct_id"], @"deleteUser: didn't set proper $distinct_id");
    STAssertNotNil([[mp.peopleQueue objectAtIndex:0] objectForKey:@"$delete"], @"deleteUser: didn't set $delete");
    STAssertEquals(mp.defaultUserId, [[mp.peopleQueue objectAtIndex:1] objectForKey:@"$distinct_id"], @"deleteCurrentUser didn't set proper default $distinct_id");
    STAssertEquals([mp.superProperties objectForKey:@"distinct_id"], distinct_id, @"identifyUser didn't set property distinct_id");
    STAssertEquals(distinct_id, [[mp.peopleQueue objectAtIndex:2] objectForKey:@"$distinct_id"], @"deleteCurrentUser didn't set proper $distinct_id");
}

- (void)testJSONSerializer {    
    NSDictionary *test = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"String", @"string",
                          [NSNumber numberWithInt:23], @"number",
                          [NSArray arrayWithObjects:@"A", @"B", @"C", nil], @"list",
                          [NSDate date], @"date",
                          nil];
    
    NSString *json = [[MPCJSONSerializer serializer] serializeArray:[NSArray arrayWithObject:test] error:nil];
    
    NSDictionary *result = [[NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] objectAtIndex:0];
    
    NSLog(@"%@ %@", [result objectForKey:@"string"], [test objectForKey:@"string"]);
    
    STAssertTrue([[test objectForKey:@"string"] isEqualToString:[result objectForKey:@"string"]], @"JSON encoding failed on string.");
    STAssertTrue([[test objectForKey:@"number"] isEqualToNumber:[result objectForKey:@"number"]], @"JSON encoding failed on number.");
    STAssertTrue([[test objectForKey:@"list"] isEqualToArray:[result objectForKey:@"list"]], @"JSON encoding failed on list.");
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    STAssertTrue([[formatter stringFromDate:[test objectForKey:@"date"]] isEqualToString:[result objectForKey:@"date"]], @"JSON encoding failed on date.");
    [formatter release];
}

- (void)testPushFormat {
    NSData *token = [@"test" dataUsingEncoding:[NSString defaultCStringEncoding]];
    [mp registerDeviceToken:token];

    NSDictionary *dict = (NSDictionary*)[mp.peopleQueue objectAtIndex:1];

    STAssertTrue(dict.count == 4, @"dictionary should have 4 items: $time, $distinct_id, $union, $token");
    STAssertTrue([dict objectForKey:@"$time"] != nil, @"time not set");
    STAssertTrue([dict objectForKey:@"$distinct_id"] != nil, @"distinct_id not set");
    STAssertTrue([dict objectForKey:@"$token"] != nil, @"token not set");

    NSDictionary *operation = [dict objectForKey:@"$union"];
    NSDictionary *targetOperation = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:@"74657374"], @"$ios_devices", nil];

    STAssertTrue([operation isEqualToDictionary:targetOperation], @"push format is incorrect");
}

@end
