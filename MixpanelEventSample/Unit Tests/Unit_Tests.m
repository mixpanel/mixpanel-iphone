//
//  Unit_Tests.m
//  Unit Tests
//

#import "Unit_Tests.h"

#import "MixpanelAPI.h"
#import "MixpanelAPI_Private.h"
#import "MPCJSONSerializer.h"

@implementation Unit_Tests

- (void)setUp {
    [super setUp];
    [MixpanelAPI sharedAPIWithToken:@"test token"];
}

- (void)tearDown {
    // Tear-down code here.
    [super tearDown];
}

- (void)testTrackFormat {
    MixpanelAPI *mp = [MixpanelAPI sharedAPI];
    
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
    MixpanelAPI *mp = [MixpanelAPI sharedAPI];
    
    NSString *value = @"John Smith";
    NSString *key = @"name";
    
    [mp setProperty:value forKey:key];
        
    STAssertTrue([mp.peopleQueue count] == 1, @"setProperty:forKey: failed. Set not in queue.");
    
    NSDictionary *person = [mp.peopleQueue objectAtIndex:0];
    
    STAssertNotNil([person objectForKey:@"$distinct_id"], @"$distinct_id does not exist.");
    STAssertNotNil([person objectForKey:@"$time"], @"$time does not exist.");
    STAssertNotNil([person objectForKey:@"$token"], @"$token does not exist.");
    STAssertNotNil([person objectForKey:@"$set"], @"$set does not exist.");
    STAssertEquals([[person objectForKey:@"$set"] objectForKey:key], value, @"property not set properly");
}

- (void)testIncrementPropertyFormat {
    MixpanelAPI *mp = [MixpanelAPI sharedAPI];
    
    NSString *key = @"numeric";
    
    [mp incrementPropertyWithKey:key];
    [mp incrementPropertyWithKey:key byInt:2];
    [mp incrementPropertyWithKey:key byNumber:[NSNumber numberWithInt:3]];
    [mp incrementProperties:[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:4], key, nil]];
    
    STAssertEquals([NSNumber numberWithInt:1], [[[mp.peopleQueue objectAtIndex:0] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey: failed.");
    STAssertEquals([NSNumber numberWithInt:2], [[[mp.peopleQueue objectAtIndex:1] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey:byInt: failed.");
    STAssertEquals([NSNumber numberWithInt:3], [[[mp.peopleQueue objectAtIndex:2] objectForKey:@"$add"] objectForKey:key], @"incrementPropertyWithKey:byNumber: failed.");
    STAssertEquals([NSNumber numberWithInt:4], [[[mp.peopleQueue objectAtIndex:3] objectForKey:@"$add"] objectForKey:key], @"incrementProperties: failed.");
}

- (void)testAppendPropertyFormat {
    MixpanelAPI *mp = [MixpanelAPI sharedAPI];
    
    NSString *key = @"property_key";
    NSString *value = @"to_append";
    
    [mp append:value toPropertyWithKey:key];
    
    STAssertEquals(value, [[[mp.peopleQueue objectAtIndex:0] objectForKey:@"$append"] objectForKey:key], @"append:toPropertyWithKey: failed.");
}

- (void)testDeleteUserFormat {
    MixpanelAPI *mp = [MixpanelAPI sharedAPI];
    
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

@end
