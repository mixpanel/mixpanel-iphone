//
//  MixpanelHierarchicalGroupsTests.m
//  HelloMixpanelTests
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelBaseTests.h"
#import "MixpanelGroup.h"
#import "MixpanelGroupPrivate.h"
#import "MixpanelPeoplePrivate.h"
#import "MixpanelPrivate.h"

// Hierarchical groups is fixed when the instance is created. These tests cover what changes when
// it is on, and that nothing changes when it is off.
@interface MixpanelHierarchicalGroupsTests : MixpanelBaseTests

@property (nonatomic, strong) NSMutableArray<NSString *> *tokens;

@end

@implementation MixpanelHierarchicalGroupsTests

- (void)setUp {
    [super setUp];
    self.tokens = [NSMutableArray array];
}

- (void)tearDown {
    for (NSString *token in self.tokens) {
        [MixpanelPersistence deleteMPUserDefaultsData:token];
        [self removeDBfile:token];
    }
    [super tearDown];
}

- (Mixpanel *)newMixpanel:(BOOL)hierarchicalGroups {
    return [self newMixpanel:hierarchicalGroups token:[self randomTokenId]];
}

- (Mixpanel *)newMixpanel:(BOOL)hierarchicalGroups token:(NSString *)token {
    [self.tokens addObject:token];
    Mixpanel *mixpanel = [[Mixpanel alloc] initWithToken:token
                                    trackAutomaticEvents:NO
                                           flushInterval:0
                                            trackCrashes:NO
                                 optOutTrackingByDefault:NO
                                     useUniqueDistinctId:NO
                                      hierarchicalGroups:hierarchicalGroups];
    // mixpanelWillFlush: returns NO, so queued records stay in the database to inspect
    mixpanel.delegate = self;
    return mixpanel;
}

- (MixpanelIdentity *)user:(NSString *)userId company:(NSString *)companyId {
    return [[MixpanelIdentity alloc] initWithUserId:userId companyId:companyId];
}

- (void)drain:(Mixpanel *)mixpanel {
    // Some work queues more work, such as identify tracking $identify
    [self waitForMixpanelQueues:mixpanel];
    [self waitForMixpanelQueues:mixpanel];
}

- (NSArray *)events:(Mixpanel *)mixpanel {
    [self drain:mixpanel];
    return [self eventQueue:mixpanel.apiToken];
}

- (NSArray *)people:(Mixpanel *)mixpanel {
    [self drain:mixpanel];
    NSArray *identified = [self peopleQueue:mixpanel.apiToken];
    NSArray *unidentified = [self unIdentifiedPeopleQueue:mixpanel.apiToken];
    return [identified arrayByAddingObjectsFromArray:unidentified];
}

- (NSArray *)groups:(Mixpanel *)mixpanel {
    [self drain:mixpanel];
    return [self groupQueue:mixpanel.apiToken];
}

- (NSDictionary *)lastEventProperties:(NSString *)eventName mixpanel:(Mixpanel *)mixpanel {
    NSArray *events = [self events:mixpanel];
    for (NSDictionary *event in events.reverseObjectEnumerator) {
        if ([event[@"event"] isEqualToString:eventName]) {
            return event[@"properties"];
        }
    }
    XCTFail(@"No %@ event was tracked", eventName);
    return nil;
}

- (NSUInteger)countEvents:(NSString *)eventName mixpanel:(Mixpanel *)mixpanel {
    NSUInteger count = 0;
    for (NSDictionary *event in [self events:mixpanel]) {
        if ([event[@"event"] isEqualToString:eventName]) {
            count++;
        }
    }
    return count;
}

#pragma mark - Events

- (void)testEventsCarryUserCompanyAndDevice {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel track:@"Viewed Report"];

    NSDictionary *props = [self lastEventProperties:@"Viewed Report" mixpanel:mixpanel];
    XCTAssertEqualObjects(props[@"$user_id"], @"user_123");
    XCTAssertEqualObjects(props[@"$company_id"], @"acme");
    XCTAssertEqualObjects(props[@"$device_id"], mixpanel.anonymousId);
    XCTAssertEqualObjects(mixpanel.identity.companyId, @"acme");
    XCTAssertEqualObjects(mixpanel.distinctId, @"$company:acme|$user:user_123");
}

- (void)testIdentifyTracksNoIdentifyEvent {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);

    // The next event carries the identity keys that tie the device to the user
    [mixpanel track:@"Viewed Report"];
    NSDictionary *props = [self lastEventProperties:@"Viewed Report" mixpanel:mixpanel];
    XCTAssertEqualObjects(props[@"$company_id"], @"acme");
    XCTAssertEqualObjects(props[@"$user_id"], @"user_123");
    XCTAssertEqualObjects(props[@"$device_id"], mixpanel.anonymousId);
}

- (void)testAnonymousEventsCarryNoCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel track:@"Opened"];

    NSDictionary *props = [self lastEventProperties:@"Opened" mixpanel:mixpanel];
    XCTAssertNil(props[@"$company_id"]);
    XCTAssertNil(props[@"$user_id"]);
    XCTAssertNotNil(props[@"$device_id"]);
}

- (void)testCompanyIdOverridesSuperProperty {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel registerSuperProperties:@{@"$company_id": @"stale"}];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel track:@"Viewed Report"];

    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$company_id"], @"acme");
}

- (void)testEventPropertyOverridesCompanyId {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel track:@"Viewed Report" properties:@{@"$company_id": @"explicit"}];

    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$company_id"], @"explicit");
}

- (void)testCompanyChangeIsAnIdentityChange {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    XCTAssertEqualObjects(mixpanel.distinctId, @"$company:acme|$user:user_123");

    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"globex"]];
    XCTAssertEqualObjects(mixpanel.distinctId, @"$company:globex|$user:user_123");

    [mixpanel track:@"Viewed Report"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$company_id"], @"globex");
}

- (void)testIdentifyWithDistinctIdDoesNothing {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    NSString *anonymous = mixpanel.distinctId;
    [mixpanel identify:@"user_123"];

    XCTAssertEqualObjects(mixpanel.distinctId, anonymous);
    XCTAssertNil(mixpanel.identity.userId);
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);
}

- (void)testIdentifyWithDistinctIdKeepsCurrentIdentity {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel identify:@"user_456" usePeople:YES];

    XCTAssertEqualObjects(mixpanel.identity.userId, @"user_123");
    XCTAssertEqualObjects(mixpanel.identity.companyId, @"acme");
    [mixpanel track:@"Viewed Report"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$company_id"], @"acme");
}

- (void)testIdentifyWithEmptyCompanyDoesNothing {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    NSString *anonymous = mixpanel.distinctId;
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@""]];

    XCTAssertEqualObjects(mixpanel.distinctId, anonymous);
    XCTAssertNil(mixpanel.identity.companyId);
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);
}

- (void)testIdentityWithoutCompanyDoesNothing {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    NSString *anonymous = mixpanel.distinctId;
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:nil]];

    XCTAssertEqualObjects(mixpanel.distinctId, anonymous);
    XCTAssertNil(mixpanel.identity.userId);
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);
}

- (void)testIdentityWithoutCompanyKeepsCurrentIdentity {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel identifyWithIdentity:[self user:@"user_456" company:nil]];

    XCTAssertEqualObjects(mixpanel.identity.userId, @"user_123");
    XCTAssertEqualObjects(mixpanel.identity.companyId, @"acme");
}

- (void)testInvalidIdentitiesDoNothing {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    NSString *anonymous = mixpanel.distinctId;
    [mixpanel identifyWithIdentity:nil];
    [mixpanel identifyWithIdentity:[self user:nil company:@"acme"]];
    [mixpanel identifyWithIdentity:[self user:@"" company:@"acme"]];

    XCTAssertEqualObjects(mixpanel.distinctId, anonymous);
    XCTAssertNil(mixpanel.identity.companyId);
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);
}

- (void)testIdentityDeviceIdIsIgnored {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    NSString *deviceId = mixpanel.anonymousId;
    [mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme" deviceId:@"some_other_device"]];

    XCTAssertEqualObjects(mixpanel.anonymousId, deviceId);
    XCTAssertEqualObjects(mixpanel.identity.userId, @"user_123");
    [mixpanel track:@"Viewed Report"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$device_id"], deviceId);
}

- (void)testGetIdentityReportsUserCompanyAndDevice {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    XCTAssertEqualObjects(mixpanel.identity, [[MixpanelIdentity alloc] initWithUserId:nil companyId:nil deviceId:mixpanel.anonymousId]);

    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    XCTAssertEqualObjects(mixpanel.identity, [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme" deviceId:mixpanel.anonymousId]);

    // What analytics reports, it accepts back unchanged
    [mixpanel identifyWithIdentity:mixpanel.identity];
    XCTAssertEqualObjects(mixpanel.identity, [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme" deviceId:mixpanel.anonymousId]);
}

- (void)testGetIdentityWhenDisabledHasNoCompany {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel identify:@"user_123"];
    XCTAssertEqualObjects(mixpanel.identity, [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:nil deviceId:mixpanel.anonymousId]);
}

#pragma mark - distinctId reports the id Mixpanel resolves the user to

- (void)testDistinctIdIsDeviceBeforeIdentify {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    XCTAssertEqualObjects(mixpanel.distinctId, [@"$device:" stringByAppendingString:mixpanel.anonymousId]);
}

- (void)testDistinctIdCombinesCompanyAndUser {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    XCTAssertEqualObjects(mixpanel.distinctId, @"$company:acme|$user:user_123");

    // Events send no distinct_id; ingestion resolves the user from the identity keys
    [mixpanel track:@"Viewed Report"];
    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"distinct_id"]);

    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"globex"]];
    XCTAssertEqualObjects(mixpanel.distinctId, @"$company:globex|$user:user_123");
}

- (void)testDistinctIdStaysOnDeviceUntilCompanyIsKnown {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identify:@"user_123"];
    XCTAssertEqualObjects(mixpanel.distinctId, [@"$device:" stringByAppendingString:mixpanel.anonymousId]);
}

- (void)testDistinctIdUnchangedWhenDisabled {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel identify:@"user_123"];
    [self drain:mixpanel];
    XCTAssertEqualObjects(mixpanel.distinctId, @"user_123");
}

- (void)testResetReturnsToDeviceDistinctId {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel reset];
    XCTAssertEqualObjects(mixpanel.distinctId, [@"$device:" stringByAppendingString:mixpanel.anonymousId]);
}

- (void)testResetClearsCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel reset];

    XCTAssertNil(mixpanel.identity.companyId);
    [mixpanel track:@"Opened"];
    XCTAssertNil([self lastEventProperties:@"Opened" mixpanel:mixpanel][@"$company_id"]);
    XCTAssertNil([MixpanelPersistence loadIdentity:mixpanel.apiToken].companyId);
}

- (void)testAliasIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel createAlias:@"new_id" forDistinctID:@"user_123"];

    XCTAssertEqual([self countEvents:@"$create_alias" mixpanel:mixpanel], 0);
    XCTAssertEqualObjects(mixpanel.identity.userId, @"user_123");
}

#pragma mark - Opt in and out

- (void)testOptInWithIdentityCarriesCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel optOutTracking];
    [mixpanel optInTrackingWithIdentity:[self user:@"user_123" company:@"acme"] properties:nil];

    NSDictionary *props = [self lastEventProperties:@"$opt_in" mixpanel:mixpanel];
    XCTAssertEqualObjects(props[@"$user_id"], @"user_123");
    XCTAssertEqualObjects(props[@"$company_id"], @"acme");
    XCTAssertEqualObjects(mixpanel.identity.companyId, @"acme");
}

- (void)testOptInWithDistinctIdIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel optOutTracking];
    [mixpanel optInTrackingForDistinctID:@"user_123"];
    [mixpanel optInTrackingForDistinctID:@"user_123" withEventProperties:nil];

    XCTAssertTrue([mixpanel hasOptedOutTracking]);
    XCTAssertEqual([self countEvents:@"$opt_in" mixpanel:mixpanel], 0);
}

- (void)testOptInWithoutArgumentsStillWorks {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel optOutTracking];
    [mixpanel optInTracking];

    XCTAssertFalse([mixpanel hasOptedOutTracking]);
    XCTAssertEqual([self countEvents:@"$opt_in" mixpanel:mixpanel], 1);
}

- (void)testOptInWithoutIdentityStaysAnonymous {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel optOutTracking];
    [mixpanel optInTrackingWithIdentity:nil properties:@{@"source": @"settings"}];

    NSDictionary *props = [self lastEventProperties:@"$opt_in" mixpanel:mixpanel];
    XCTAssertEqualObjects(props[@"source"], @"settings");
    XCTAssertNil(props[@"$company_id"]);
    XCTAssertNil(props[@"$user_id"]);
}

- (void)testOptInWithIdentityWhenDisabled {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel optOutTracking];
    [mixpanel optInTrackingWithIdentity:[self user:@"user_123" company:nil] properties:nil];

    XCTAssertFalse([mixpanel hasOptedOutTracking]);
    XCTAssertEqualObjects([self lastEventProperties:@"$opt_in" mixpanel:mixpanel][@"$user_id"], @"user_123");
}

- (void)testOptOutDeletesUserWithoutClearingCharges {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    // optOutTracking checks for an identified user synchronously, as it does without
    // hierarchical groups, so let identify land first
    [self drain:mixpanel];
    [mixpanel optOutTracking];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    NSDictionary *message = groups.firstObject;
    XCTAssertNotNil(message[@"$delete"]);
    XCTAssertEqualObjects(message[@"$group_key"], @"$user_id");
    XCTAssertEqualObjects(message[@"$group_id"], @"user_123");
    XCTAssertEqualObjects(message[@"$company_id"], @"acme");
    XCTAssertEqual([self people:mixpanel].count, 0);
}

- (void)testOptOutClearsCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel optOutTracking];
    [self drain:mixpanel];

    XCTAssertNil(mixpanel.identity.companyId);
    XCTAssertNil([MixpanelPersistence loadIdentity:mixpanel.apiToken].companyId);
}

#pragma mark - Disabled: behaves exactly as before

- (void)testIdentifyWithCompanyIsIgnoredWhenDisabled {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    NSString *anonymous = mixpanel.distinctId;
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];

    XCTAssertEqualObjects(mixpanel.distinctId, anonymous);
    XCTAssertNil(mixpanel.identity.companyId);
    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 0);
}

- (void)testDisabledSendsPeopleToEngage {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel identify:@"user_123"];
    [mixpanel.people set:@{@"plan": @"pro"}];
    [mixpanel.people increment:@{@"logins": @1}];
    [mixpanel track:@"Viewed Report"];

    NSArray *people = [self people:mixpanel];
    XCTAssertEqual(people.count, 2);
    XCTAssertEqual([self groups:mixpanel].count, 0);
    XCTAssertEqualObjects(people.firstObject[@"$distinct_id"], @"user_123");
    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"$company_id"]);
}

- (void)testIdentityWithoutCompanyWorksWhenDisabled {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:nil]];

    XCTAssertEqual([self countEvents:@"$identify" mixpanel:mixpanel], 1);
    XCTAssertEqualObjects(mixpanel.distinctId, @"user_123");
}

#pragma mark - User profiles

- (void)testPeopleUpdatesBecomeUserIdGroupProfiles {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    MixpanelPeople *people = mixpanel.people;
    [people set:@{@"plan": @"pro"}];
    [people setOnce:@{@"first_seen": @"today"}];
    [people union:@{@"roles": @[@"admin"]}];
    [people remove:@{@"roles": @"viewer"}];
    [people unset:@[@"legacy"]];
    [people deleteUser];

    XCTAssertEqual([self people:mixpanel].count, 0);
    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 6);
    NSArray *operations = @[@"$set", @"$set_once", @"$union", @"$remove", @"$unset", @"$delete"];
    for (NSUInteger i = 0; i < operations.count && i < groups.count; i++) {
        NSDictionary *message = groups[i];
        XCTAssertNotNil(message[operations[i]], @"%@", operations[i]);
        XCTAssertEqualObjects(message[@"$group_key"], @"$user_id");
        XCTAssertEqualObjects(message[@"$group_id"], @"user_123");
        XCTAssertEqualObjects(message[@"$company_id"], @"acme");
        XCTAssertNotNil(message[@"$token"]);
        XCTAssertNotNil(message[@"$time"]);
        XCTAssertNil(message[@"$distinct_id"]);
        XCTAssertNil(message[@"$device_id"]);
        XCTAssertNil(message[@"$user_id"]);
    }
    XCTAssertEqualObjects(groups[0][@"$set"][@"plan"], @"pro");
    // Platform extras stay in the operation payload
    [self assertDefaultPeopleProperties:groups[0][@"$set"]];
    XCTAssertEqualObjects(groups[4][@"$unset"], @[@"legacy"]);
}

- (void)testUnsupportedPeopleOperationsAreDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    MixpanelPeople *people = mixpanel.people;
    [people increment:@{@"logins": @1}];
    [people append:@{@"history": @"a"}];
    [people merge:@{@"settings": @{@"theme": @"dark"}}];
    [people trackCharge:@9.99];
    [people clearCharges];

    XCTAssertEqual([self people:mixpanel].count, 0);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testPeopleUpdatesBeforeIdentifyAreDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel.people set:@{@"plan": @"pro"}];

    XCTAssertEqual([self people:mixpanel].count, 0);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testPeopleUpdatesWithoutCompanyAreDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identify:@"user_123"];
    [mixpanel.people set:@{@"plan": @"pro"}];

    XCTAssertEqual([self people:mixpanel].count, 0);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testSetGroupWritesUserProfileThroughGroups {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@"finance"];

    XCTAssertEqual([self people:mixpanel].count, 0);
    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    XCTAssertEqualObjects(groups.firstObject[@"$group_key"], @"$user_id");
    XCTAssertEqualObjects(groups.firstObject[@"$set"][@"team"], @"finance");
}

#pragma mark - Custom group membership: one group per key, stored as a single value

- (void)testSetGroupSendsSingleValueOnEvents {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@"finance"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"], @"finance");
    XCTAssertEqualObjects(mixpanel.currentSuperProperties[@"team"], @"finance");
}

- (void)testSetGroupWithListIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupIDs:@[@"finance"]];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testSetGroupWithArrayValueIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@[@"finance"]];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testSetGroupWithSeveralGroupsIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupIDs:@[@"finance", @"sales"]];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testAddGroupIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel addGroup:@"team" groupID:@"finance"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testAddGroupToSecondGroupIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@"finance"];
    [mixpanel addGroup:@"team" groupID:@"sales"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"], @"finance");
    XCTAssertEqual([self groups:mixpanel].count, 1);
}

- (void)testRemoveGroupClearsTheGroup {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@"finance"];
    [mixpanel removeGroup:@"team" groupID:@"finance"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 2);
    XCTAssertEqualObjects(groups.lastObject[@"$unset"], @[@"team"]);
    XCTAssertEqualObjects(groups.lastObject[@"$group_key"], @"$user_id");
}

- (void)testRemoveOtherGroupDoesNothing {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel setGroup:@"team" groupID:@"finance"];
    [mixpanel removeGroup:@"team" groupID:@"sales"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"], @"finance");
    XCTAssertEqual([self groups:mixpanel].count, 1);
}

- (void)testRemoveGroupClearsListStoredBeforeHierarchicalGroups {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel registerSuperProperties:@{@"team": @[@"finance"]}];
    [mixpanel removeGroup:@"team" groupID:@"finance"];
    [mixpanel track:@"Viewed Report"];

    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"]);
}

- (void)testDisabledGroupMembershipStaysAList {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel setGroup:@"team" groupID:@"finance"];
    [mixpanel addGroup:@"team" groupID:@"sales"];
    [mixpanel track:@"Viewed Report"];

    NSArray *expected = @[@"finance", @"sales"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"], expected);
}

- (void)testTrackWithGroupsSendsSingleValue {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel trackWithGroups:@"Viewed Report" properties:@{@"page": @"home"} groups:@{@"team": @"finance"}];

    NSDictionary *properties = [self lastEventProperties:@"Viewed Report" mixpanel:mixpanel];
    XCTAssertEqualObjects(properties[@"team"], @"finance");
    XCTAssertEqualObjects(properties[@"page"], @"home");
}

- (void)testTrackWithGroupsWithListIsDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [mixpanel trackWithGroups:@"Viewed Report"
                   properties:@{@"page": @"home"}
                       groups:@{@"region": @"emea", @"team": @[@"finance", @"sales"]}];
    [mixpanel trackWithGroups:@"Viewed Report" properties:nil groups:@{@"team": @[@"finance"]}];
    [mixpanel trackWithGroups:@"Viewed Report" properties:nil groups:@{@"team": [NSSet setWithObject:@"finance"]}];

    XCTAssertEqual([self countEvents:@"Viewed Report" mixpanel:mixpanel], 0);
}

- (void)testDisabledTrackWithGroupsSendsList {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel trackWithGroups:@"Viewed Report"
                   properties:@{@"page": @"home"}
                       groups:@{@"team": @[@"finance", @"sales"]}];

    NSArray *expected = @[@"finance", @"sales"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:mixpanel][@"team"], expected);
}

#pragma mark - Group profiles

- (void)testGroupUpdatesCarryCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [[mixpanel getGroup:@"$company_id" groupID:@"acme"] set:@{@"tier": @"enterprise"}];
    [[mixpanel getGroup:@"team" groupID:@"finance"] set:@{@"size": @12}];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 2);
    NSDictionary *company = groups.firstObject;
    XCTAssertEqualObjects(company[@"$group_key"], @"$company_id");
    XCTAssertEqualObjects(company[@"$group_id"], @"acme");
    XCTAssertEqualObjects(company[@"$company_id"], @"acme");
    XCTAssertNil(company[@"$set"][@"$company_id"]);

    NSDictionary *team = groups.lastObject;
    XCTAssertEqualObjects(team[@"$group_key"], @"team");
    XCTAssertEqualObjects(team[@"$company_id"], @"acme");
}

- (void)testDeleteGroupCarriesCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [[mixpanel getGroup:@"team" groupID:@"finance"] deleteGroup];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    XCTAssertNotNil(groups.firstObject[@"$delete"]);
    XCTAssertEqualObjects(groups.firstObject[@"$company_id"], @"acme");
}

- (void)testGetCompanyUpdatesIdentifiedCompany {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [[mixpanel getCompany] set:@{@"tier": @"enterprise"}];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    NSDictionary *message = groups.firstObject;
    XCTAssertEqualObjects(message[@"$group_key"], @"$company_id");
    XCTAssertEqualObjects(message[@"$group_id"], @"acme");
    XCTAssertEqualObjects(message[@"$company_id"], @"acme");
    XCTAssertEqualObjects(message[@"$set"][@"tier"], @"enterprise");
    MixpanelGroup *company = [mixpanel getCompany];
    XCTAssertEqualObjects(company.groupKey, @"$company_id");
    XCTAssertEqualObjects(company.groupID, @"acme");
}

- (void)testGetCompanyBeforeIdentifyIsNil {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    XCTAssertNil([mixpanel getCompany]);
}

- (void)testGetCompanyWhenDisabledIsNil {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [mixpanel identify:@"user_123"];
    XCTAssertNil([mixpanel getCompany]);
}

- (void)testGetCompanyKeepsTheCompanyAtCallTime {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    MixpanelGroup *company = [mixpanel getCompany];
    [mixpanel identifyWithIdentity:[self user:@"user_123" company:@"globex"]];
    [company set:@{@"tier": @"enterprise"}];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    XCTAssertEqualObjects(groups.firstObject[@"$group_id"], @"acme");
}

- (void)testGroupUpdatesWithoutCompanyAreDropped {
    Mixpanel *mixpanel = [self newMixpanel:YES];
    [[mixpanel getGroup:@"team" groupID:@"finance"] set:@{@"size": @12}];

    XCTAssertEqual([self groups:mixpanel].count, 0);
}

- (void)testDisabledGroupUpdatesCarryNoCompany {
    Mixpanel *mixpanel = [self newMixpanel:NO];
    [[mixpanel getGroup:@"team" groupID:@"finance"] set:@{@"size": @12}];

    NSArray *groups = [self groups:mixpanel];
    XCTAssertEqual(groups.count, 1);
    XCTAssertNil(groups.firstObject[@"$company_id"]);
}

#pragma mark - Persistence

- (void)testCompanyPersistsAcrossLaunches {
    NSString *token = [self randomTokenId];
    Mixpanel *first = [self newMixpanel:YES token:token];
    [first identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [self drain:first];
    XCTAssertEqualObjects([MixpanelPersistence loadIdentity:token].companyId, @"acme");

    // A new instance for the same token unarchives the identity
    Mixpanel *second = [self newMixpanel:YES token:token];
    XCTAssertEqualObjects(second.identity.userId, @"user_123");
    XCTAssertEqualObjects(second.identity.companyId, @"acme");
    XCTAssertEqualObjects(second.distinctId, @"$company:acme|$user:user_123");
    [second track:@"Viewed Report"];
    XCTAssertEqualObjects([self lastEventProperties:@"Viewed Report" mixpanel:second][@"$company_id"], @"acme");
}

- (void)testPersistedCompanyIsIgnoredWhenDisabled {
    NSString *token = [self randomTokenId];
    Mixpanel *first = [self newMixpanel:YES token:token];
    [first identifyWithIdentity:[self user:@"user_123" company:@"acme"]];
    [self drain:first];

    Mixpanel *second = [self newMixpanel:NO token:token];
    XCTAssertNil(second.identity.companyId);
    [second track:@"Viewed Report"];
    XCTAssertNil([self lastEventProperties:@"Viewed Report" mixpanel:second][@"$company_id"]);
}

#pragma mark - MixpanelIdentity and the option

- (void)testIdentityInitializers {
    XCTAssertNil([[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:nil].companyId);
    XCTAssertNil([[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme"].deviceId);
    XCTAssertEqualObjects([[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme" deviceId:@"device_abc"].deviceId, @"device_abc");
}

- (void)testIdentityIsValueEqual {
    MixpanelIdentity *a = [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"acme" deviceId:nil];
    MixpanelIdentity *b = [[MixpanelIdentity alloc] initWithUserId:[@"user_" stringByAppendingString:@"123"] companyId:@"acme"];
    XCTAssertEqualObjects(a, b);
    XCTAssertEqual(a.hash, b.hash);
    XCTAssertNotEqualObjects(a, [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:@"globex"]);
    XCTAssertNotEqualObjects(a, [[MixpanelIdentity alloc] initWithUserId:@"user_123" companyId:nil]);
    XCTAssertEqualObjects([[MixpanelIdentity alloc] initWithUserId:nil companyId:nil], [[MixpanelIdentity alloc] initWithUserId:nil companyId:nil]);
}

- (void)testIdentityDescriptionOmitsNils {
    XCTAssertEqualObjects([[MixpanelIdentity alloc] initWithUserId:@"u" companyId:@"c"].description, @"MixpanelIdentity(userId=u, companyId=c)");
    XCTAssertEqualObjects([[MixpanelIdentity alloc] initWithUserId:@"u" companyId:nil].description, @"MixpanelIdentity(userId=u)");
    XCTAssertEqualObjects([[MixpanelIdentity alloc] initWithUserId:nil companyId:nil deviceId:@"d"].description, @"MixpanelIdentity(deviceId=d)");
}

- (void)testOptionDefaultsToDisabled {
    Mixpanel *mixpanel = [[Mixpanel alloc] initWithToken:[self randomTokenId] trackAutomaticEvents:NO andFlushInterval:60];
    [self.tokens addObject:mixpanel.apiToken];
    XCTAssertFalse(mixpanel.hierarchicalGroups);
    XCTAssertTrue([self newMixpanel:YES].hierarchicalGroups);
}

@end

