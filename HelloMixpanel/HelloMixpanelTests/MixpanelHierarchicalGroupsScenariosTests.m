//
//  MixpanelHierarchicalGroupsScenariosTests.m
//  HelloMixpanelTests
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelGroup.h"
#import "MixpanelPeoplePrivate.h"
#import "MixpanelPrivate.h"

static NSString *const TRACK = @"/track/";
static NSString *const ENGAGE = @"/engage/";
static NSString *const GROUPS = @"/groups/";

static NSString *const USER_ID = @"my_user_id";
static NSString *const COMPANY_ID = @"my_company_id";
static NSString *const TEAM_ID = @"my_team_id";

// The hierarchical groups scenarios from the Notion testing doc, one test per section and in the
// same order.
//
// Each test asserts the endpoint a call hits and the request it sends, or that nothing is sent.
// This SDK queues each endpoint in its own table (events to /track, people to /engage, groups to
// /groups), so the requests are read back from those queues; the delegate keeps them from being
// flushed. Edge cases beyond the doc live in MixpanelHierarchicalGroupsTests.
@interface MixpanelHierarchicalGroupsScenariosTests : MixpanelBaseTests

@end

@implementation MixpanelHierarchicalGroupsScenariosTests

- (void)setUp {
    [super setUp];
    self.mixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId]
                               trackAutomaticEvents:NO
                                      flushInterval:0
                                       trackCrashes:NO
                            optOutTrackingByDefault:NO
                                useUniqueDistinctId:NO
                                 hierarchicalGroups:YES];
    // mixpanelWillFlush: returns NO, so queued requests stay in the database to inspect
    self.mixpanel.delegate = self;
}

- (void)tearDown {
    [self drain];
    [MixpanelPersistence deleteMPUserDefaultsData:self.mixpanel.apiToken];
    [self removeDBfile:self.mixpanel.apiToken];
    [super tearDown];
}

- (void)drain {
    // Some work queues more work, such as identify tracking $identify
    [self waitForMixpanelQueues:self.mixpanel];
    [self waitForMixpanelQueues:self.mixpanel];
}

- (MixpanelIdentity *)user:(NSString *)userId company:(NSString *)companyId {
    return [[MixpanelIdentity alloc] initWithUserId:userId companyId:companyId];
}

- (void)identify {
    [self.mixpanel identifyWithIdentity:[self user:USER_ID company:COMPANY_ID]];
}

// Every request queued so far, as @{@"endpoint": ..., @"body": ...}, events then people then groups
- (NSArray<NSDictionary *> *)sent {
    [self drain];
    NSString *token = self.mixpanel.apiToken;
    NSMutableArray *sent = [NSMutableArray array];
    for (NSDictionary *body in [self eventQueue:token]) {
        [sent addObject:@{@"endpoint": TRACK, @"body": body}];
    }
    NSArray *people = [[self peopleQueue:token] arrayByAddingObjectsFromArray:[self unIdentifiedPeopleQueue:token]];
    for (NSDictionary *body in people) {
        [sent addObject:@{@"endpoint": ENGAGE, @"body": body}];
    }
    for (NSDictionary *body in [self groupQueue:token]) {
        [sent addObject:@{@"endpoint": GROUPS, @"body": body}];
    }
    return sent;
}

// Starts a scenario from what the steps before it set up, so it asserts only its own requests
- (void)clearSent {
    [self drain];
    dispatch_sync(self.mixpanel.serialQueue, ^{
        [self.mixpanel.persistence resetEntities];
    });
}

- (void)assertNothingSent {
    NSArray *sent = [self sent];
    XCTAssertEqual(sent.count, 0, @"Expected no requests: %@", sent);
}

- (NSDictionary *)onlySent:(NSString *)endpoint {
    NSArray *sent = [self sent];
    XCTAssertEqual(sent.count, 1, @"Expected exactly one request: %@", sent);
    XCTAssertEqualObjects(sent.firstObject[@"endpoint"], endpoint);
    return sent.firstObject[@"body"];
}

- (NSDictionary *)onlyEvent:(NSString *)eventName {
    NSDictionary *event = [self onlySent:TRACK];
    XCTAssertEqualObjects(event[@"event"], eventName);
    return event[@"properties"];
}

- (NSString *)deviceDistinctId {
    return [@"$device:" stringByAppendingString:self.mixpanel.anonymousId];
}

- (void)assertAnonymous:(NSDictionary *)props {
    XCTAssertEqualObjects(props[@"distinct_id"], [self deviceDistinctId]);
    XCTAssertEqualObjects(props[@"$device_id"], self.mixpanel.anonymousId);
    XCTAssertNil(props[@"$user_id"]);
    XCTAssertNil(props[@"$company_id"]);
}

- (void)assertIdentified:(NSDictionary *)props {
    XCTAssertEqualObjects(props[@"distinct_id"], USER_ID);
    XCTAssertEqualObjects(props[@"$user_id"], USER_ID);
    XCTAssertEqualObjects(props[@"$company_id"], COMPANY_ID);
    XCTAssertEqualObjects(props[@"$device_id"], self.mixpanel.anonymousId);
}

// Asserts the single /groups request has exactly these top-level keys beside its one operation,
// and returns the value of the operation. Each record is sent with "id", its row in the queue, so
// every expected key set includes it.
- (id)onlyGroupsUpdate:(NSString *)groupKey groupId:(NSString *)groupId operation:(NSString *)operation keys:(NSArray *)messageKeys {
    NSDictionary *message = [self onlySent:GROUPS];
    NSSet *expectedKeys = [NSSet setWithArray:[messageKeys arrayByAddingObject:operation]];
    XCTAssertEqualObjects([NSSet setWithArray:message.allKeys], expectedKeys);
    XCTAssertEqualObjects(message[@"$group_key"], groupKey);
    XCTAssertEqualObjects(message[@"$group_id"], groupId);
    XCTAssertEqualObjects(message[@"$company_id"], COMPANY_ID);
    return message[operation];
}

- (id)onlyGroupsUpdate:(NSString *)groupKey groupId:(NSString *)groupId operation:(NSString *)operation {
    // Group profile updates (MixpanelGroup) carry no $mp_metadata
    return [self onlyGroupsUpdate:groupKey groupId:groupId operation:operation
                             keys:@[@"$token", @"$time", @"$group_key", @"$group_id", @"$company_id", @"id"]];
}

- (id)onlyUserUpdate:(NSString *)operation {
    // User profile updates go through people, which adds $mp_metadata
    return [self onlyGroupsUpdate:@"$user_id" groupId:USER_ID operation:operation
                             keys:@[@"$token", @"$time", @"$group_key", @"$group_id", @"$company_id", @"$mp_metadata", @"id"]];
}

#pragma mark - Track (Anonymous)

- (void)testTrackAnonymous {
    [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];

    NSDictionary *props = [self onlyEvent:@"HG Event!"];
    [self assertAnonymous:props];
    XCTAssertEqualObjects(props[@"source"], @"hierarchical_groups_page");
}

#pragma mark - Identify

- (void)testIdentify {
    NSString *anonymousDistinctId = [self deviceDistinctId];
    [self identify];

    NSDictionary *props = [self onlyEvent:@"$identify"];
    [self assertIdentified:props];
    XCTAssertEqualObjects(props[@"$anon_distinct_id"], anonymousDistinctId);
}

#pragma mark - Track (Identified)

- (void)testTrackIdentified {
    [self identify];
    [self clearSent];
    [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];

    NSDictionary *props = [self onlyEvent:@"HG Event!"];
    [self assertIdentified:props];
    XCTAssertEqualObjects(props[@"source"], @"hierarchical_groups_page");
}

#pragma mark - Set User Property

- (void)testSetUserProperty {
    [self identify];
    [self clearSent];
    [self.mixpanel.people set:@"plan" to:@"enterprise"];

    NSDictionary *set = [self onlyUserUpdate:@"$set"];
    XCTAssertEqualObjects(set[@"plan"], @"enterprise");
    [self assertDefaultPeopleProperties:set];
}

#pragma mark - Set User Properties

- (void)testSetUserProperties {
    [self identify];
    [self clearSent];
    [self.mixpanel.people set:@{@"role": @"admin", @"seats": @5}];

    NSDictionary *set = [self onlyUserUpdate:@"$set"];
    XCTAssertEqualObjects(set[@"role"], @"admin");
    XCTAssertEqualObjects(set[@"seats"], @5);
    [self assertDefaultPeopleProperties:set];
}

#pragma mark - Set Once User Property

- (void)testSetOnceUserProperty {
    [self identify];
    [self clearSent];
    [self.mixpanel.people setOnce:@{@"first_seen": @"2026-10-27"}];

    NSDictionary *setOnce = [self onlyUserUpdate:@"$set_once"];
    XCTAssertEqualObjects(setOnce[@"first_seen"], @"2026-10-27");
    // The $ios_* device properties are added to $set_once as well as $set
    [self assertDefaultPeopleProperties:setOnce];
}

#pragma mark - Union User Property

- (void)testUnionUserProperty {
    [self identify];
    [self clearSent];
    [self.mixpanel.people union:@{@"devices": @[@"android"]}];

    XCTAssertEqualObjects([self onlyUserUpdate:@"$union"], (@{@"devices": @[@"android"]}));
}

#pragma mark - Remove User Property

- (void)testRemoveUserProperty {
    [self identify];
    [self clearSent];
    [self.mixpanel.people remove:@{@"devices": @"android"}];

    XCTAssertEqualObjects([self onlyUserUpdate:@"$remove"], (@{@"devices": @"android"}));
}

#pragma mark - Unset User Property

- (void)testUnsetUserProperty {
    [self identify];
    [self clearSent];
    [self.mixpanel.people unset:@[@"plan"]];

    XCTAssertEqualObjects([self onlyUserUpdate:@"$unset"], @[@"plan"]);
}

#pragma mark - Delete User

- (void)testDeleteUser {
    [self identify];
    [self clearSent];
    [self.mixpanel.people deleteUser];

    XCTAssertEqualObjects([self onlyUserUpdate:@"$delete"], @{});
}

#pragma mark - Clear Charges (Unsupported)

- (void)testClearChargesIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel.people clearCharges];

    [self assertNothingSent];
}

#pragma mark - Increment User Property (Unsupported)

- (void)testIncrementUserPropertyIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel.people increment:@"logins" by:@1.0];
    [self.mixpanel.people increment:@{@"logins": @1, @"sessions": @2}];

    [self assertNothingSent];
}

#pragma mark - Append User Property (Unsupported)

- (void)testAppendUserPropertyIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel.people append:@{@"history": @"opened_hg_page"}];

    [self assertNothingSent];
}

#pragma mark - Merge User Property (Unsupported)

- (void)testMergeUserPropertyIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel.people merge:@{@"settings": @{@"theme": @"dark"}}];

    [self assertNothingSent];
}

#pragma mark - Track Charge (Unsupported)

- (void)testTrackChargeIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel.people trackCharge:@9.99];

    [self assertNothingSent];
}

#pragma mark - Set Company Property

- (void)testSetCompanyProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] set:@{@"tier": @"enterprise"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$set"], (@{@"tier": @"enterprise"}));
}

- (void)testGetCompanyIsTheCompanyGroup {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"$company_id" groupID:COMPANY_ID] set:@{@"tier": @"enterprise"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$set"], (@{@"tier": @"enterprise"}));
}

#pragma mark - Set Company Properties

- (void)testSetCompanyProperties {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] set:@{@"size": @12, @"region": @"us"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$set"], (@{@"size": @12, @"region": @"us"}));
}

#pragma mark - Set Once Company Property

- (void)testSetOnceCompanyProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] setOnce:@{@"created": @"2026-10-27"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$set_once"], (@{@"created": @"2026-10-27"}));
}

#pragma mark - Union Company Property

- (void)testUnionCompanyProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] union:@"tags" values:@[@"android"]];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$union"], (@{@"tags": @[@"android"]}));
}

#pragma mark - Remove Company Property

- (void)testRemoveCompanyProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] remove:@"tags" value:@"android"];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$remove"], (@{@"tags": @"android"}));
}

#pragma mark - Unset Company Property

- (void)testUnsetCompanyProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] unset:@"tier"];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$unset"], @[@"tier"]);
}

#pragma mark - Set User's Custom Group (setGroup)

- (void)testSetUsersCustomGroup {
    [self identify];
    [self clearSent];
    [self.mixpanel setGroup:@"team_id" groupID:TEAM_ID];

    NSDictionary *set = [self onlyUserUpdate:@"$set"];
    XCTAssertEqualObjects(set[@"team_id"], TEAM_ID);
    [self assertDefaultPeopleProperties:set];
}

#pragma mark - Track with Custom Group (trackWithGroups)

- (void)testTrackWithCustomGroup {
    [self identify];
    [self clearSent];
    [self.mixpanel trackWithGroups:@"HG Team Event!" properties:@{} groups:@{@"team_id": TEAM_ID}];

    NSDictionary *props = [self onlyEvent:@"HG Team Event!"];
    [self assertIdentified:props];
    XCTAssertEqualObjects(props[@"team_id"], TEAM_ID);
}

#pragma mark - Track (After setGroup)

- (void)testTrackAfterSetGroup {
    [self identify];
    [self.mixpanel setGroup:@"team_id" groupID:TEAM_ID];
    [self clearSent];
    [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];

    NSDictionary *props = [self onlyEvent:@"HG Event!"];
    [self assertIdentified:props];
    // A single value, not a list: hierarchical groups would read ["my_team_id"] as one group
    XCTAssertEqualObjects(props[@"team_id"], TEAM_ID);
    XCTAssertEqualObjects(props[@"source"], @"hierarchical_groups_page");
}

#pragma mark - Remove User's Custom Group (removeGroup)

- (void)testRemoveUsersCustomGroup {
    [self identify];
    [self.mixpanel setGroup:@"team_id" groupID:TEAM_ID];
    [self clearSent];
    [self.mixpanel removeGroup:@"team_id" groupID:TEAM_ID];

    XCTAssertEqualObjects([self onlyUserUpdate:@"$unset"], @[@"team_id"]);
    XCTAssertNil(self.mixpanel.currentSuperProperties[@"team_id"]);
}

#pragma mark - Set Custom Group Property

- (void)testSetCustomGroupProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] set:@{@"tier": @"enterprise"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$set"], (@{@"tier": @"enterprise"}));
}

#pragma mark - Set Custom Group Properties

- (void)testSetCustomGroupProperties {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] set:@{@"size": @12, @"region": @"us"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$set"], (@{@"size": @12, @"region": @"us"}));
}

#pragma mark - Set Once Custom Group Property

- (void)testSetOnceCustomGroupProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] setOnce:@{@"created": @"2026-10-27"}];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$set_once"], (@{@"created": @"2026-10-27"}));
}

#pragma mark - Union Custom Group Property

- (void)testUnionCustomGroupProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] union:@"tags" values:@[@"android"]];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$union"], (@{@"tags": @[@"android"]}));
}

#pragma mark - Remove Custom Group Property

- (void)testRemoveCustomGroupProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] remove:@"tags" value:@"android"];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$remove"], (@{@"tags": @"android"}));
}

#pragma mark - Unset Custom Group Property

- (void)testUnsetCustomGroupProperty {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] unset:@"tier"];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$unset"], @[@"tier"]);
}

#pragma mark - Delete Company

- (void)testDeleteCompany {
    [self identify];
    [self clearSent];
    [[self.mixpanel getCompany] deleteGroup];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"$company_id" groupId:COMPANY_ID operation:@"$delete"], @{});
}

#pragma mark - Delete Custom Group

- (void)testDeleteCustomGroup {
    [self identify];
    [self clearSent];
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] deleteGroup];

    XCTAssertEqualObjects([self onlyGroupsUpdate:@"team_id" groupId:TEAM_ID operation:@"$delete"], @{});
}

#pragma mark - Reset

- (void)testReset {
    [self identify];
    [self.mixpanel setGroup:@"team_id" groupID:TEAM_ID];
    [self drain];
    NSString *deviceId = self.mixpanel.anonymousId;
    [self clearSent];
    [self.mixpanel reset];

    // reset also empties the queues, so this checks it queued nothing after clearing them
    [self assertNothingSent];
    MixpanelIdentity *identity = self.mixpanel.identity;
    XCTAssertNil(identity.userId);
    XCTAssertNil(identity.companyId);
    XCTAssertNotEqualObjects(identity.deviceId, deviceId);
    XCTAssertEqual(self.mixpanel.currentSuperProperties.count, 0);
    XCTAssertFalse([self.mixpanel hasOptedOutTracking]);
}

#pragma mark - Track (After Reset)

- (void)testTrackAfterReset {
    [self identify];
    [self.mixpanel setGroup:@"team_id" groupID:TEAM_ID];
    [self.mixpanel reset];
    [self clearSent];
    [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];

    NSDictionary *props = [self onlyEvent:@"HG Event!"];
    [self assertAnonymous:props];
    XCTAssertNil(props[@"team_id"]);
}

#pragma mark - Opt Out (Identified)

- (void)testOptOutIdentified {
    [self identify];
    // optOutTracking checks for an identified user synchronously, so let identify land first
    [self drain];
    NSString *deviceId = self.mixpanel.anonymousId;
    [self clearSent];
    [self.mixpanel optOutTracking];

    // The user's profile is deleted; there is no clearCharges $unset of $transactions
    XCTAssertEqualObjects([self onlyUserUpdate:@"$delete"], @{});
    XCTAssertTrue([self.mixpanel hasOptedOutTracking]);
    MixpanelIdentity *identity = self.mixpanel.identity;
    XCTAssertNil(identity.userId);
    XCTAssertNil(identity.companyId);
    XCTAssertNotEqualObjects(identity.deviceId, deviceId);
}

#pragma mark - Opt Out (Anonymous)

- (void)testOptOutAnonymous {
    NSString *deviceId = self.mixpanel.anonymousId;
    [self.mixpanel optOutTracking];

    [self assertNothingSent];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking]);
    XCTAssertNotEqualObjects(self.mixpanel.anonymousId, deviceId);
}

#pragma mark - Track (Opted Out)

- (void)testTrackOptedOut {
    [self.mixpanel optOutTracking];
    [self clearSent];
    [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];

    [self assertNothingSent];
}

#pragma mark - Opt In (Anonymous)

- (void)testOptInAnonymous {
    [self.mixpanel optOutTracking];
    [self clearSent];
    [self.mixpanel optInTracking];

    NSDictionary *props = [self onlyEvent:@"$opt_in"];
    // Opt-out sets the distinct id to the bare new device id, without the $device: prefix
    XCTAssertEqualObjects(props[@"distinct_id"], self.mixpanel.anonymousId);
    XCTAssertEqualObjects(props[@"$device_id"], self.mixpanel.anonymousId);
    XCTAssertNil(props[@"$user_id"]);
    XCTAssertNil(props[@"$company_id"]);
    XCTAssertFalse([self.mixpanel hasOptedOutTracking]);
}

#pragma mark - Opt In With Identity

- (void)testOptInWithIdentity {
    [self.mixpanel optOutTracking];
    [self clearSent];
    [self.mixpanel optInTrackingWithIdentity:[self user:USER_ID company:COMPANY_ID] properties:nil];

    // $identify and $opt_in, both carrying the user and company, in either order
    NSArray *sent = [self sent];
    XCTAssertEqual(sent.count, 2);
    NSMutableSet *events = [NSMutableSet set];
    for (NSDictionary *request in sent) {
        XCTAssertEqualObjects(request[@"endpoint"], TRACK);
        [events addObject:request[@"body"][@"event"]];
        [self assertIdentified:request[@"body"][@"properties"]];
    }
    XCTAssertEqualObjects(events, ([NSSet setWithArray:@[@"$identify", @"$opt_in"]]));
    XCTAssertFalse([self.mixpanel hasOptedOutTracking]);
}

#pragma mark - Identify Without Company (Unsupported)

- (void)testIdentifyWithoutCompanyIsUnsupported {
    MixpanelIdentity *before = self.mixpanel.identity;
    [self.mixpanel identifyWithIdentity:[self user:USER_ID company:nil]];

    [self assertNothingSent];
    XCTAssertEqualObjects(self.mixpanel.identity, before);
}

#pragma mark - Identify With Distinct ID (Unsupported)

- (void)testIdentifyWithDistinctIdIsUnsupported {
    MixpanelIdentity *before = self.mixpanel.identity;
    [self.mixpanel identify:USER_ID];

    [self assertNothingSent];
    XCTAssertEqualObjects(self.mixpanel.identity, before);
}

#pragma mark - Alias (Unsupported)

- (void)testAliasIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel createAlias:@"new_alias" forDistinctID:USER_ID];

    [self assertNothingSent];
    XCTAssertEqualObjects(self.mixpanel.identity.userId, USER_ID);
}

#pragma mark - Opt In With Distinct ID (Unsupported)

- (void)testOptInWithDistinctIdIsUnsupported {
    [self.mixpanel optOutTracking];
    [self clearSent];
    [self.mixpanel optInTrackingForDistinctID:USER_ID];

    [self assertNothingSent];
    XCTAssertTrue([self.mixpanel hasOptedOutTracking]);
}

#pragma mark - Set User's Custom Groups With a List (Unsupported)

- (void)testSetUsersCustomGroupsWithAListIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel setGroup:@"team_id" groupIDs:@[TEAM_ID]];

    [self assertNothingSent];
    XCTAssertNil(self.mixpanel.currentSuperProperties[@"team_id"]);
}

#pragma mark - Add User's Custom Group (Unsupported)

- (void)testAddUsersCustomGroupIsUnsupported {
    [self identify];
    [self clearSent];
    [self.mixpanel addGroup:@"team_id" groupID:TEAM_ID];

    [self assertNothingSent];
    XCTAssertNil(self.mixpanel.currentSuperProperties[@"team_id"]);
}

#pragma mark - Set User Property Before Identify (Unsupported)

- (void)testSetUserPropertyBeforeIdentifyIsUnsupported {
    [self.mixpanel.people set:@"plan" to:@"enterprise"];

    [self assertNothingSent];
}

#pragma mark - Set Company Property Before Identify (Unsupported)

- (void)testSetCompanyPropertyBeforeIdentifyIsUnsupported {
    XCTAssertNil([self.mixpanel getCompany]);

    [self assertNothingSent];
}

#pragma mark - Set Custom Group Property Before Identify (Unsupported)

- (void)testSetCustomGroupPropertyBeforeIdentifyIsUnsupported {
    [[self.mixpanel getGroup:@"team_id" groupID:TEAM_ID] set:@{@"tier": @"enterprise"}];

    [self assertNothingSent];
}

@end

