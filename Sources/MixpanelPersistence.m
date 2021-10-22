//
//  MixpanelPersistence.m
//  Mixpanel
//
//  Created by Jared McFarland on 10/1/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import "MixpanelPersistence.h"
#import "MPLogger.h"
#import "MixpanelPrivate.h"

@implementation MixpanelPersistence : NSObject

@synthesize apiToken = _apiToken;
@synthesize mpdb = _mpdb;

NSString *kLegacyArchiveTypeEvents = @"events";
NSString *kLegacyArchiveTypePeople = @"people";
NSString *kLegacyArchiveTypeGropus = @"groups";
NSString *kLegacyArchiveTypeProperties = @"properties";
NSString *kLegacyArchiveTypeOptOutStatus = @"optOutStatus";

NSString *kDefaultKeySuiteName = @"Mixpanel";
NSString *kDefaultKeyPrefix = @"mixpanel";
NSString *kDefaultKeyOptOutStatus = @"OptOutStatus";
NSString *kDefaultKeyAutomaticEventEnabled = @"AutomaticEventEnabled";
NSString *kDefaultKeyAutomaticEventEnabledFromDecide = @"AutomaticEventEnabledFromDecide";
NSString *kDefaultKeyTimedEvents = @"timedEvents";
NSString *kDefaultKeySuperProperties = @"superProperties";
NSString *kDefaultKeyDistinctId = @"MPDistinctID";
NSString *kDefaultKeyPeopleDistinctId = @"MPPeopleDistinctID";
NSString *kDefaultKeyAnonymousId = @"MPAnonymousId";
NSString *kDefaultKeyUserId = @"MPUserId";
NSString *kDefaultKeyAlias = @"MPAlias";
NSString *kDefaultKeyHadPersistedDistinctId = @"MPHadPersistedDistinctId";

- (instancetype) initWithToken:(NSString *)token {
    self = [super init];
    if (self) {
        self.apiToken = token;
        self.mpdb = [[MPDB alloc] initWithToken:token];
    }
    return self;
}

- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type flag:(bool)flag {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:entity options:kNilOptions error:&error];
    if (!error) {
        [self.mpdb insertRow:type data:data flag:flag];
    }
}

- (void)saveEntities:(NSArray *)entities type:(NSString *)type flag:(bool)flag {
    for (NSDictionary *entity in entities) {
        [self saveEntity:entity type:type flag:flag];
    }
}

- (NSArray *)loadEntitiesInBatch:(NSString *)type batchSize:(int)batchSize flag:(bool)flag {
    return [self.mpdb readRows:type numRows:batchSize flag:flag];
}

- (void)removeEntitiesInBatch:(NSString *)type ids:(NSArray *)ids {
    [self.mpdb deleteRows:type ids:ids];
}

- (void)identifyPeople {
    [self.mpdb updateRowsFlag:@"people" newFlag:false];
}

- (void) resetEntities {
    for (NSString *type in @[@"events", @"people", @"groups"]) {
        [self.mpdb deleteRows:type ids:@[]];
    }
}

+ (void) saveOptOutStatusFlag:(bool)value apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        [defaults setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]];
        [defaults synchronize];
    }
}

+ (bool) loadOptOutStatusFlag:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        return [defaults boolForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]];
    }
    return nil;
}

+ (void) saveAutomaticEventsEnabledFlag:(bool)value fromDecide:(bool)fromDecide apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        if (fromDecide) {
            [defaults setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabledFromDecide]];
        } else {
            [defaults setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabled]];
        }
        [defaults synchronize];
    }
}

+ (bool) loadAutomaticEventsEnabledFlag:(NSString *)apiToken {
//    #if TV_AUTO_EVENTS
//    return true
//    #else
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSString *automaticEventsEnabledKey = [NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabled];
        NSString *automaticEventsEnabledFromDecideKey = [NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabledFromDecide];
        if ([defaults objectForKey:automaticEventsEnabledKey] == nil && [defaults objectForKey:automaticEventsEnabledFromDecideKey] == nil) {
            return true; // default true
        }
        if ([defaults objectForKey:automaticEventsEnabledKey] != nil) {
            return [defaults boolForKey:automaticEventsEnabledKey];
        } else { // if there is no local settings, get the value from Decide
            return [defaults boolForKey:automaticEventsEnabledFromDecideKey];
        }
    }
    return nil;
}

+ (void) saveTimedEvents:(NSDictionary *)timedEvents apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *timedEventsData = [NSKeyedArchiver archivedDataWithRootObject:timedEvents];
        [defaults setValue:timedEventsData forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyTimedEvents]];
        [defaults synchronize];
    }
}

+ (NSDictionary *) loadTimedEvents:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *timedEventsData = [defaults dataForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyTimedEvents]];
        if (timedEventsData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:timedEventsData];
        }
    }
    return @{};
}

+ (void) saveSuperProperties:(NSDictionary *)superProperties apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *superPropertiesData = [NSKeyedArchiver archivedDataWithRootObject:superProperties];
        [defaults setValue:superPropertiesData forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeySuperProperties]];
        [defaults synchronize];
    }
}

+ (NSDictionary *) loadSuperProperties:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *superPropertiesData = [defaults dataForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeySuperProperties]];
        if (superPropertiesData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:superPropertiesData];
        }
    }
    return @{};
}

+ (void) saveIdentity:(NSDictionary *)mixpanelIdentity apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityDistinctId] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyDistinctId]];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityPeopleDistinctId] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyPeopleDistinctId]];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityAnonymousId] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAnonymousId]];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityUserId] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyUserId]];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityAlias] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAlias]];
        [defaults setValue: [mixpanelIdentity valueForKey:kMixpanelIdentityHadPersistedDistinctId] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyHadPersistedDistinctId]];
        [defaults synchronize];
    }
}

+ (NSDictionary *) loadIdentity:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        return @{
            kMixpanelIdentityDistinctId: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyDistinctId]],
            kMixpanelIdentityPeopleDistinctId: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyPeopleDistinctId]],
            kMixpanelIdentityAnonymousId: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAnonymousId]],
            kMixpanelIdentityUserId: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyUserId]],
            kMixpanelIdentityAlias: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAlias]],
            kMixpanelIdentityHadPersistedDistinctId: [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyHadPersistedDistinctId]],
        };
    }
    return @{
        kMixpanelIdentityDistinctId: @"",
        kMixpanelIdentityPeopleDistinctId: @"",
        kMixpanelIdentityAnonymousId: @"",
        kMixpanelIdentityUserId: @"",
        kMixpanelIdentityAlias: @"",
        kMixpanelIdentityHadPersistedDistinctId: @"",
    };
}

+ (void) deleteMPUserDefaultsData:(NSString *)apiToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyDistinctId]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyPeopleDistinctId]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAnonymousId]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyUserId]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAlias]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyHadPersistedDistinctId]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabled]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabledFromDecide]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyTimedEvents]];
        [defaults removeObjectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeySuperProperties]];
        [defaults synchronize];
    }
}

- (void)migrate
{
    if (![self needMigration]) {
        return;
    }
    NSArray *unarchivedEntities = [self unarchive];
    [self saveEntities:unarchivedEntities[0] type:kPersistenceTypeEvents flag:false];
    [self saveEntities:unarchivedEntities[1] type:kPersistenceTypePeople flag:true];
    [self saveEntities:unarchivedEntities[2] type:kPersistenceTypeGroups flag:false];
    NSDictionary *properties = unarchivedEntities[3];
    [MixpanelPersistence saveSuperProperties:properties[@"superProperties"] apiToken:self.apiToken];
    [MixpanelPersistence saveTimedEvents:properties[@"timedEvents"] apiToken:self.apiToken];
    [MixpanelPersistence saveIdentity:@{
        kMixpanelIdentityDistinctId: properties[@"distinctId"],
        kMixpanelIdentityAnonymousId: properties[@"anonymousId"],
        kMixpanelIdentityUserId: properties[@"userId"],
        kMixpanelIdentityAlias: properties[@"alias"],
        kMixpanelIdentityHadPersistedDistinctId: properties[@"hadPersistedDistinctId"],
        kMixpanelIdentityPeopleDistinctId: properties[@"peopleDistinctId"],
    } apiToken:self.apiToken];
    [MixpanelPersistence saveOptOutStatusFlag:unarchivedEntities[4] != 0 apiToken:self.apiToken];
    [MixpanelPersistence saveAutomaticEventsEnabledFlag:properties[@"automaticEvents"] != 0 fromDecide:NO apiToken:self.apiToken];
}

- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
#if !defined(MIXPANEL_TVOS)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
}

- (NSString *)eventsFilePath
{
    return [self filePathFor:@"events"];
}

- (NSString *)peopleFilePath
{
    return [self filePathFor:@"people"];
}

- (NSString *)groupsFilePath
{
    return [self filePathFor:@"groups"];
}

- (NSString *)propertiesFilePath
{
    return [self filePathFor:@"properties"];
}

- (NSString *)variantsFilePath
{
    return [self filePathFor:@"variants"];
}

- (NSString *)eventBindingsFilePath
{
    return [self filePathFor:@"event_bindings"];
}

- (NSString *)optOutFilePath
{
    return [self filePathFor:@"optOut"];
}

- (void)removeArchivedFileAtPath:(NSString *)filePath
{
    NSError *error;
    [NSFileManager.defaultManager removeItemAtPath:filePath error:&error];
    if (error) {
        MPLogError(@"Unable to remove file at path: %@, error: %@", filePath, error);
    }
}

- (NSArray *)unarchive
{
    NSArray *eventsQueue = [self unarchiveEvents];
    NSArray *peopleQueue = [self unarchivePeople];
    NSArray *groupsQueue = [self unarchiveGroups];
    NSDictionary *properties = [self unarchiveProperties];
    NSNumber *optOutStatus = [self unarchiveOptOut];
    
    [self removeArchivedFileAtPath:[self eventsFilePath]];
    [self removeArchivedFileAtPath:[self peopleFilePath]];
    [self removeArchivedFileAtPath:[self groupsFilePath]];
    [self removeArchivedFileAtPath:[self propertiesFilePath]];
    [self removeArchivedFileAtPath:[self optOutFilePath]];
    
    return @[eventsQueue, peopleQueue, groupsQueue, properties, optOutStatus];
}

+ (nonnull id)unarchiveOrDefaultFromFile:(NSString *)filePath asClass:(Class)class
{
    return [self unarchiveFromFile:filePath asClass:class] ?: [class new];
}

+ (id)unarchiveFromFile:(NSString *)filePath asClass:(Class)class
{
    id unarchivedData = nil;
    @try {
        if (@available(iOS 11, macOS 10.13, tvOS 11, watchOS 4, *)) {
            NSError *error = nil;
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            unarchivedData = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
            if (error) {
                MPLogError(@"%@ got error while unarchiving data in %@: %@", self, filePath, error);
            }
        } else {
            unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        }
        // this check is inside the try-catch as the unarchivedData may be a non-NSObject, not responding to `isKindOfClass:` or `respondsToSelector:`
        if (![unarchivedData isKindOfClass:class]) {
            unarchivedData = nil;
        }
        MPLogInfo(@"%@ unarchived data from %@: %@", self, filePath, unarchivedData);
    }
    @catch (NSException *exception) {
        MPLogError(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        // Reset un archived data
        unarchivedData = nil;
        // Remove the (possibly) corrupt data from the disk
        NSError *error = NULL;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (!removed) {
            MPLogWarning(@"%@ unable to remove archived file at %@ - %@", self, filePath, error);
        }
    }
    return unarchivedData;
}

- (NSArray *)unarchiveEvents
{
    return (NSArray *)[MixpanelPersistence unarchiveOrDefaultFromFile:[self eventsFilePath] asClass:[NSArray class]];
}

- (NSArray *)unarchivePeople
{
    return (NSArray *)[MixpanelPersistence unarchiveOrDefaultFromFile:[self peopleFilePath] asClass:[NSArray class]];
}

- (NSArray *)unarchiveGroups
{
    return (NSArray *)[MixpanelPersistence unarchiveOrDefaultFromFile:[self groupsFilePath] asClass:[NSArray class]];
}

- (NSDictionary *)unarchiveProperties
{
    return (NSDictionary *)[MixpanelPersistence unarchiveFromFile:[self propertiesFilePath] asClass:[NSDictionary class]];
}


- (NSNumber *)unarchiveOptOut
{
    return (NSNumber *)[MixpanelPersistence unarchiveOrDefaultFromFile:[self optOutFilePath] asClass:[NSNumber class]];
}

- (bool)needMigration
{
    NSFileManager *manager = [NSFileManager defaultManager];
    return [manager fileExistsAtPath:[self eventsFilePath]] ||
    [manager fileExistsAtPath:[self peopleFilePath]] ||
    [manager fileExistsAtPath:[self groupsFilePath]] ||
    [manager fileExistsAtPath:[self propertiesFilePath]] ||
    [manager fileExistsAtPath:[self optOutFilePath]];
}
@end
