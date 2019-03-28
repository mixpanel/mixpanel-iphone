//
//  SelectorEvaluatorTests.m
//  HelloMixpanel
//
//  Created by Madhu Palani on 3/15/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SelectorEvaluator.h"

@interface TestSelectorEvaluator : SelectorEvaluator
@end

@interface SelectorEvaluatorTests : XCTestCase
@end

@implementation SelectorEvaluatorTests

- (void) testToNumber {
    NSError *error = nil;
    [SelectorEvaluator toNumber:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid type");
    [SelectorEvaluator toNumber:[[NSDate alloc] initWithTimeIntervalSince1970:0] withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid value for date");
    XCTAssertEqual([SelectorEvaluator toNumber:[NSNumber numberWithBool:YES] withError:&error], 1);
    XCTAssertEqual([SelectorEvaluator toNumber:[NSNumber numberWithBool:NO] withError:&error], 0);
    XCTAssertEqual([SelectorEvaluator toNumber:[NSNumber numberWithDouble:100.9] withError:&error], 100.9);
    XCTAssertEqual([SelectorEvaluator toNumber:[NSNumber numberWithInteger:101] withError:&error], 101);
    XCTAssertEqual([SelectorEvaluator toNumber:@"100.1" withError:&error], 100.1);
    XCTAssertEqual([SelectorEvaluator toNumber:@"abc" withError:&error], 0);
}

- (void) testToBoolean {
    XCTAssertFalse([SelectorEvaluator toBoolean:nil]);
    XCTAssertTrue([SelectorEvaluator toBoolean:[NSNumber numberWithBool:YES]]);
    XCTAssertFalse([SelectorEvaluator toBoolean:[NSNumber numberWithBool:NO]]);
    XCTAssertTrue([SelectorEvaluator toBoolean:[NSNumber numberWithInteger:100]]);
    XCTAssertTrue([SelectorEvaluator toBoolean:[NSNumber numberWithDouble:0.1]]);
    XCTAssertTrue([SelectorEvaluator toBoolean:[NSNumber numberWithInteger:-1]]);
    XCTAssertFalse([SelectorEvaluator toBoolean:[NSNumber numberWithInteger:0]]);
    XCTAssertFalse([SelectorEvaluator toBoolean:[NSNumber numberWithDouble:0.0]]);
    XCTAssertTrue([SelectorEvaluator toBoolean:@"abc"]);
    XCTAssertFalse([SelectorEvaluator toBoolean:@""]);
    XCTAssertTrue([SelectorEvaluator toBoolean:(@[@1, @2])]);
    XCTAssertFalse([SelectorEvaluator toBoolean:(@[])]);
    XCTAssertTrue([SelectorEvaluator toBoolean:(@{@"1": @1})]);
    XCTAssertFalse([SelectorEvaluator toBoolean:(@{})]);
    XCTAssertTrue([SelectorEvaluator toBoolean:[[NSDate alloc] initWithTimeIntervalSince1970:100]]);
    XCTAssertFalse([SelectorEvaluator toBoolean:[[NSDate alloc] initWithTimeIntervalSince1970:0]]);
    XCTAssertFalse([SelectorEvaluator toBoolean:[NSObject alloc]]);
}

- (void) testEvaluateNumber {
    NSError *error = nil;
    [SelectorEvaluator evaluateNumber:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    [SelectorEvaluator evaluateNumber:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    [SelectorEvaluator evaluateNumber:@{@"operator": @"number"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    [SelectorEvaluator evaluateNumber:@{@"operator": @"number", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    [SelectorEvaluator evaluateNumber:@{@"operator": @"number", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    [SelectorEvaluator evaluateNumber:@{@"operator": @"number", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: number");
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[NSDate alloc] initWithTimeIntervalSince1970:1]}) withError:nil] intValue], 1);
    XCTAssertNil((NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:&error]);
    XCTAssertNil((NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[]}) withError:&error]);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil] intValue], 1);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @NO}) withError:nil] intValue], 0);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @100}) withError:nil] intValue], 100);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @100.1}) withError:nil] doubleValue], 100.1);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"100.1"}) withError:nil] doubleValue], 100.1);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"100"}) withError:nil] intValue], 100);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"abc"}) withError:nil] intValue], 0);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateNumber:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @""}) withError:nil] intValue], 0);
}

- (void) testEvaluateBoolean {
    NSError *error = nil;
    [SelectorEvaluator evaluateBoolean:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    [SelectorEvaluator evaluateBoolean:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    [SelectorEvaluator evaluateBoolean:@{@"operator": @"boolean"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    [SelectorEvaluator evaluateBoolean:@{@"operator": @"boolean", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    [SelectorEvaluator evaluateBoolean:@{@"operator": @"boolean", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    [SelectorEvaluator evaluateBoolean:@{@"operator": @"boolean", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: boolean");
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @NO}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @100}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @0}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"0"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @""}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[@1, @2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{@"a": @1}}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[NSDate alloc] initWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateBoolean:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[NSDate alloc] initWithTimeIntervalSince1970:0]}) withError:nil] value]);
}

- (void) testEvaluateDatetime {
    NSError *error = nil;
    [SelectorEvaluator evaluateDateTime:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    [SelectorEvaluator evaluateDateTime:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    [SelectorEvaluator evaluateDateTime:@{@"operator": @"datetime"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    [SelectorEvaluator evaluateDateTime:@{@"operator": @"datetime", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    [SelectorEvaluator evaluateDateTime:@{@"operator": @"datetime", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    [SelectorEvaluator evaluateDateTime:@{@"operator": @"datetime", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: datetime");
    
    XCTAssertNil([SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil], [[NSDate alloc] initWithTimeIntervalSince1970:1]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @NO}) withError:nil], [[NSDate alloc] initWithTimeIntervalSince1970:0]);
    XCTAssertEqualObjects((NSDate *)[SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[NSDate alloc] initWithTimeIntervalSince1970:10]}) withError:nil], [[NSDate alloc] initWithTimeIntervalSince1970:10]);
    NSDateFormatter *formatter = [SelectorEvaluator dateFormatter];
    NSDate *date = [formatter dateFromString:@"2019-02-01T12:01:01"];
    XCTAssertEqualObjects((NSDate *)[SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"2019-02-01T12:01:01"}) withError:nil], date);
    XCTAssertNil([SelectorEvaluator evaluateDateTime:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"2019-14-32T13:00:00"}) withError:nil]);
}

- (void) testEvaluateList {
    NSError *error = nil;
    [SelectorEvaluator evaluateList:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    [SelectorEvaluator evaluateList:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    [SelectorEvaluator evaluateList:@{@"operator": @"list"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    [SelectorEvaluator evaluateList:@{@"operator": @"list", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    [SelectorEvaluator evaluateList:@{@"operator": @"list", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    [SelectorEvaluator evaluateList:@{@"operator": @"list", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: list");
    
    XCTAssertNil([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @1}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @""}) withError:nil]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[]}) withError:nil], @[]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateList:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[@1, @2]}) withError:nil], (@[@1, @2]));
}

- (void) testEvaluateString {
    NSError *error = nil;
    [SelectorEvaluator evaluateString:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    [SelectorEvaluator evaluateString:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    [SelectorEvaluator evaluateString:@{@"operator": @"string"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    [SelectorEvaluator evaluateString:@{@"operator": @"string", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    [SelectorEvaluator evaluateString:@{@"operator": @"string", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    [SelectorEvaluator evaluateString:@{@"operator": @"string", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: string");
    
    NSDateFormatter *formatter = [SelectorEvaluator dateFormatter];
    NSDate *date = [formatter dateFromString:@"2019-02-01T12:01:01"];
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": date}) withError:nil], @"2019-02-01T12:01:01");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @100}) withError:nil], @"100");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[]}) withError:nil], @"[]");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[@1, @"123", @2]}) withError:nil], @"[1,\"123\",2]");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil], @"{}");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{@"a": @"b"}}) withError:nil], @"{\"a\":\"b\"}");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"blah"}) withError:nil], @"blah");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil], @"1");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @NO}) withError:nil], @"0");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[MPBoolean alloc] init:YES]}) withError:nil], @"YES");
    XCTAssertEqualObjects([SelectorEvaluator evaluateString:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[MPBoolean alloc] init:NO]}) withError:nil], @"NO");
}

- (void) testEvaluateAnd {
    NSError *error = nil;
    [SelectorEvaluator evaluateAnd:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    [SelectorEvaluator evaluateAnd:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    [SelectorEvaluator evaluateAnd:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    [SelectorEvaluator evaluateAnd:@{@"operator": @"and", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    [SelectorEvaluator evaluateAnd:@{@"operator": @"and", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    [SelectorEvaluator evaluateAnd:@{@"operator": @"and", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: and");
    
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateAnd:(@{@"operator": @"and", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateAnd:(@{@"operator": @"and", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @NO}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateAnd:(@{@"operator": @"and", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateAnd:(@{@"operator": @"and", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @NO}) withError:nil] value]);
}

- (void) testEvaluateOr {
    NSError *error = nil;
    [SelectorEvaluator evaluateOr:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    [SelectorEvaluator evaluateOr:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    [SelectorEvaluator evaluateOr:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    [SelectorEvaluator evaluateOr:@{@"operator": @"or", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    [SelectorEvaluator evaluateOr:@{@"operator": @"or", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    [SelectorEvaluator evaluateOr:@{@"operator": @"or", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: or");
    
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateOr:(@{@"operator": @"or", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @YES}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateOr:(@{@"operator": @"or", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @NO}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateOr:(@{@"operator": @"or", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateOr:(@{@"operator": @"or", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @NO}) withError:nil] value]);
}

- (void) testEvaluateIn {
    NSError *error = nil;
    [SelectorEvaluator evaluateIn:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    [SelectorEvaluator evaluateIn:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    [SelectorEvaluator evaluateIn:@{@"operator": @"in"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    [SelectorEvaluator evaluateIn:@{@"operator": @"in", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    [SelectorEvaluator evaluateIn:@{@"operator": @"in", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    [SelectorEvaluator evaluateIn:@{@"operator": @"in", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: in");
    
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abcd"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@11]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abdc"}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"not in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"not in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abcd"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"not in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@11]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateIn:(@{@"operator": @"not in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abdc"}) withError:nil] value]);
}

- (void) testEvaluatePlus {
    NSError *error = nil;
    [SelectorEvaluator evaluatePlus:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");
    [SelectorEvaluator evaluatePlus:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");
    [SelectorEvaluator evaluatePlus:@{@"operator": @"+"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");
    [SelectorEvaluator evaluatePlus:@{@"operator": @"+", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");
    [SelectorEvaluator evaluatePlus:@{@"operator": @"+", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");
    [SelectorEvaluator evaluatePlus:@{@"operator": @"+", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: +");

    XCTAssertNil([SelectorEvaluator evaluatePlus:(@{@"operator": @"+", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@1, @2]}) withError:nil]);
    XCTAssertEqualObjects([SelectorEvaluator evaluatePlus:(@{@"operator": @"+", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:3]);
    XCTAssertEqualObjects([SelectorEvaluator evaluatePlus:(@{@"operator": @"+", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"1", @"prop2": @"2"}) withError:nil], @"12");
}

- (void) testEvaluateArithmetic {
    NSError *error = nil;
    [SelectorEvaluator evaluateArithmetic:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    [SelectorEvaluator evaluateArithmetic:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    [SelectorEvaluator evaluateArithmetic:@{@"operator": @"-"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    [SelectorEvaluator evaluateArithmetic:@{@"operator": @"-", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    [SelectorEvaluator evaluateArithmetic:@{@"operator": @"-", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    [SelectorEvaluator evaluateArithmetic:@{@"operator": @"-", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid arithmetic operator");
    
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"-", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:-1]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"*", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:2]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"/", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithDouble:0.5]);
    XCTAssertNil([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"/", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @0}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @0}) withError:nil]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @0, @"prop2": @1}) withError:nil], [NSNumber numberWithInt:0]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @-1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:1]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @-1, @"prop2": @-2}) withError:nil], [NSNumber numberWithInt:-1]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateArithmetic:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @-2}) withError:nil], [NSNumber numberWithInt:-1]);
}

- (void) testEquality {
    NSError *error = nil;
    [SelectorEvaluator evaluateEquality:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    [SelectorEvaluator evaluateEquality:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    [SelectorEvaluator evaluateEquality:@{@"operator": @"=="} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    [SelectorEvaluator evaluateEquality:@{@"operator": @"==", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    [SelectorEvaluator evaluateEquality:@{@"operator": @"==", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    [SelectorEvaluator evaluateEquality:@{@"operator": @"==", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid (not) equality operator");
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @"1"}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @YES}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @NO}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @NO}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"property": @"literal", @"value": @YES}]}) properties:(@{@"prop1": @YES}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"property": @"literal", @"value": @NO}]}) properties:(@{@"prop1": @NO}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"property": @"literal", @"value": @NO}]}) properties:(@{@"prop1": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"property": @"literal", @"value": @YES}]}) properties:(@{@"prop1": @NO}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abc"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"bac"}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:100], @"prop2": [NSDate dateWithTimeIntervalSince1970:100]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:100], @"prop2": [NSDate dateWithTimeIntervalSince1970:101]}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @{@"a": @1, @"b": @2}, @"prop2": @{@"b": @2, @"a": @1}}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @{@"a": @1, @"b": @2}, @"prop2": @{@"a": @2, @"b": @1}}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @[@1, @2], @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @[@1, @2], @"prop2": @[@2, @1]}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @"1"}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @NO}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @NO}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"abc"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"abc", @"prop2": @"bac"}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:100], @"prop2": [NSDate dateWithTimeIntervalSince1970:100]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:100], @"prop2": [NSDate dateWithTimeIntervalSince1970:101]}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @{@"a": @1, @"b": @2}, @"prop2": @{@"b": @2, @"a": @1}}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @{@"a": @1, @"b": @2}, @"prop2": @{@"a": @2, @"b": @1}}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @[@1, @2], @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateEquality:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @[@1, @2], @"prop2": @[@2, @1]}) withError:nil] value]);
}

- (void) testComparison {
    NSError *error = nil;
    [SelectorEvaluator evaluateComparison:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    [SelectorEvaluator evaluateComparison:@{@"operator": @"and"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    [SelectorEvaluator evaluateComparison:@{@"operator": @">"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    [SelectorEvaluator evaluateComparison:@{@"operator": @">", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    [SelectorEvaluator evaluateComparison:@{@"operator": @">", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    [SelectorEvaluator evaluateComparison:@{@"operator": @">", @"children": @[@[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid comparison operator");
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @2, @"prop2": @1}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @2, @"prop2": @1}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @2, @"prop2": @1}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @2, @"prop2": @1}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);

    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:2]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:1], @"prop2": [NSDate dateWithTimeIntervalSince1970:2]}) withError:nil] value]);

    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:2], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:2], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:2], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": [NSDate dateWithTimeIntervalSince1970:2], @"prop2": [NSDate dateWithTimeIntervalSince1970:1]}) withError:nil] value]);

    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"2"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"2"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"2"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"2"}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"2", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"2", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"2", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateComparison:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"2", @"prop2": @"12"}) withError:nil] value]);
}

- (void) testEvaluateDefined {
    NSError *error = nil;
    [SelectorEvaluator evaluateDefined:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    [SelectorEvaluator evaluateDefined:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    [SelectorEvaluator evaluateDefined:@{@"operator": @"defined"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    [SelectorEvaluator evaluateDefined:@{@"operator": @"defined", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    [SelectorEvaluator evaluateDefined:@{@"operator": @"defined", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    [SelectorEvaluator evaluateDefined:@{@"operator": @"defined", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: defined");
    
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateDefined:(@{@"operator": @"defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateDefined:(@{@"operator": @"defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil] value]);
    
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateDefined:(@{@"operator": @"not defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateDefined:(@{@"operator": @"not defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil] value]);
}

- (void) testEvaluateNot {
    NSError *error = nil;
    [SelectorEvaluator evaluateNot:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    [SelectorEvaluator evaluateNot:@{@"operator": @"or"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    [SelectorEvaluator evaluateNot:@{@"operator": @"not"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    [SelectorEvaluator evaluateNot:@{@"operator": @"not", @"children": @{@"invalid": @"type"}} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    [SelectorEvaluator evaluateNot:@{@"operator": @"not", @"children": @[]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    [SelectorEvaluator evaluateNot:@{@"operator": @"not", @"children": @[@[], @[]]} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator: not");
    
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @NO}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @1}) withError:nil] value]);
    
    XCTAssertNil([SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[]}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"1"}) withError:nil]);
    XCTAssertNil([SelectorEvaluator evaluateNot:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil]);
}

- (void) testEvaluateWindow {
    NSError *error = nil;
    [TestSelectorEvaluator evaluateWindow:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key window");
    [TestSelectorEvaluator evaluateWindow:@{@"window": @{}} withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key value");
    [TestSelectorEvaluator evaluateWindow:@{@"window": @{@"value": @{}}} withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key value");
    [TestSelectorEvaluator evaluateWindow:@{@"window": @{@"value": @1}} withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key unit");
    [TestSelectorEvaluator evaluateWindow:@{@"window": @{@"value": @1, @"unit": @"blah"}} withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid unit for window");
    
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateWindow:(@{@"window": @{@"value": @-2, @"unit": @"hour"}}) withError:&error], [NSDate dateWithTimeIntervalSince1970:1000+(2*60*60)]);
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateWindow:(@{@"window": @{@"value": @-2, @"unit": @"day"}}) withError:&error], [NSDate dateWithTimeIntervalSince1970:1000+(2*24*60*60)]);
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateWindow:(@{@"window": @{@"value": @-2, @"unit": @"week"}}) withError:&error], [NSDate dateWithTimeIntervalSince1970:1000+(2*7*24*60*60)]);
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateWindow:(@{@"window": @{@"value": @-2, @"unit": @"month"}}) withError:&error], [NSDate dateWithTimeIntervalSince1970:1000+(2*30*24*60*60)]);
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateWindow:(@{@"window": @{@"value": @2, @"unit": @"hour"}}) withError:&error], [NSDate dateWithTimeIntervalSince1970:1000+(-2*60*60)]);
}

- (void) testEvaluateOperand {
    NSError *error = nil;
    [SelectorEvaluator evaluateOperand:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key property");
    [SelectorEvaluator evaluateOperand:@{@"property": @1} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key property");
    [SelectorEvaluator evaluateOperand:@{@"property": @"event"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid or missing required key value");
    [SelectorEvaluator evaluateOperand:@{@"property": @"event", @"value": @1} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid type for event property name");
    [SelectorEvaluator evaluateOperand:@{@"property": @"blah", @"value": @"1"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid value for property key");
    
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateOperand:(@{@"property": @"event", @"value": @"prop"}) properties:(@{@"prop": @1}) withError:nil] intValue], 1);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperand:(@{@"property": @"literal", @"value": @"prop"}) properties:(@{@"prop": @1}) withError:nil], @"prop");
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateOperand:(@{@"property": @"literal", @"value": @"now"}) properties:(@{@"prop": @1}) withError:nil], [NSDate dateWithTimeIntervalSince1970:1000]);
    XCTAssertEqualObjects([TestSelectorEvaluator evaluateOperand:(@{@"property": @"literal", @"value": @{@"window": @{@"value": @-1, @"unit": @"hour"}}}) properties:(@{@"prop": @1}) withError:nil], [NSDate dateWithTimeIntervalSince1970:1000+(60*60)]);
}

- (void) testEvaluateOperator {
    NSError *error = nil;
    [SelectorEvaluator evaluateOperator:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator key");
    [SelectorEvaluator evaluateOperator:@{@"operator": @1} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator key");
    [SelectorEvaluator evaluateOperator:@{@"operator": @"blah"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"unknown operator blah");
    
    XCTAssertTrue([(MPBoolean *) [SelectorEvaluator evaluateOperator:(@{@"operator": @"and", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @YES, @"prop2": @YES}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *) [SelectorEvaluator evaluateOperator:(@{@"operator": @"or", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @NO, @"prop2": @YES}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *) [SelectorEvaluator evaluateOperator:(@{@"operator": @"in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *) [SelectorEvaluator evaluateOperator:(@{@"operator": @"not in", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @10, @"prop2": @[@1, @2]}) withError:nil] value]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"+", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:3]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"-", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:-1]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"*", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithInt:2]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"/", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithDouble:0.5]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"%", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @2}) withError:nil], [NSNumber numberWithDouble:1]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @"==", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @1, @"prop2": @1}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @"!=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @[@1, @2], @"prop2": @[@2, @1]}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @">", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @">=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @"<=", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertFalse([(MPBoolean *)[SelectorEvaluator evaluateOperator:(@{@"operator": @"<", @"children": @[@{@"property": @"event", @"value": @"prop1"}, @{@"property": @"event", @"value": @"prop2"}]}) properties:(@{@"prop1": @"12", @"prop2": @"12"}) withError:nil] value]);
    XCTAssertEqual([(NSNumber*)[SelectorEvaluator evaluateOperator:(@{@"operator": @"number", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @YES}) withError:nil] intValue], 1);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateOperator:(@{@"operator": @"boolean", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @{}}) withError:nil] value]);
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"list", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @[@1, @2]}) withError:nil], (@[@1, @2]));
    XCTAssertEqualObjects([SelectorEvaluator evaluateOperator:(@{@"operator": @"string", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": [[MPBoolean alloc] init:NO]}) withError:nil], @"NO");
    NSDateFormatter *formatter = [SelectorEvaluator dateFormatter];
    NSDate *date = [formatter dateFromString:@"2019-02-01T12:01:01"];
    XCTAssertEqualObjects((NSDate *)[SelectorEvaluator evaluateOperator:(@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{@"prop": @"2019-02-01T12:01:01"}) withError:nil], date);
    XCTAssertFalse([(MPBoolean*)[SelectorEvaluator evaluateOperator:(@{@"operator": @"defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateOperator:(@{@"operator": @"not defined", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
    XCTAssertTrue([(MPBoolean*)[SelectorEvaluator evaluateOperator:(@{@"operator": @"not", @"children": @[@{@"property": @"event", @"value": @"prop"}]}) properties:(@{}) withError:nil] value]);
}

- (void) testEvaluate {
    NSError *error = nil;
    [SelectorEvaluator evaluate:nil properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"invalid operator key");
    [SelectorEvaluator evaluate:@{@"operator": @"blah"} properties:nil withError:&error];
    XCTAssertEqualObjects([error localizedDescription], @"unknown operator blah");
    
    XCTAssertTrue([(NSNumber *) [SelectorEvaluator evaluate:(@{@"operator": @">", @"children": @[@{@"operator": @"datetime", @"children": @[@{@"property": @"event", @"value": @"prop1"}]}, @{@"property": @"literal", @"value": @{@"window": @{@"value": @1, @"unit": @"hour"}}}]}) properties:(@{@"prop1": [NSDate date]}) withError:nil] boolValue]);
}

@end

@implementation TestSelectorEvaluator
+(NSDate *) currentDate {
    return [NSDate dateWithTimeIntervalSince1970:1000];
}
@end
