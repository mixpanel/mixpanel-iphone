//
//  MixpanelPersistence.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelPersistence.h"
#import "MPLogger.h"
#import "MixpanelPrivate.h"
#import "MPJSONHander.h"


@interface MixpanelPersistence()

@property (nonatomic, readonly) MPDB *mpdb;

@end

@implementation MixpanelPersistence : NSObject


static NSString *const kLegacyArchiveTypeEvents = @"events";
static NSString *const kLegacyArchiveTypePeople = @"people";
static NSString *const kLegacyArchiveTypeGroups = @"groups";
static NSString *const kLegacyArchiveTypeProperties = @"properties";
static NSString *const kLegacyArchiveTypeOptOutStatus = @"optOut";

static NSString *const kLegacyDefaultKeySuperProperties = @"superProperties";
static NSString *const kLegacyDefaultKeyTimeEvents = @"timedEvents";
static NSString *const kLegacyDefaultKeyAutomaticEvents = @"automaticEvents";
static NSString *const kLegacyDefaultKeyPeopleUnidentifiedQueue = @"peopleUnidentifiedQueue";
static NSString *const kLegacyDefaultKeyDistinctId = @"distinctId";
static NSString *const kLegacyDefaultKeyPeopleDistinctId = @"peopleDistinctId";
static NSString *const kLegacyDefaultKeyAnonymousId = @"anonymousId";
static NSString *const kLegacyDefaultKeyUserId = @"userId";
static NSString *const kLegacyDefaultKeyAlias = @"alias";
static NSString *const kLegacyDefaultKeyHadPersistedDistinctId = @"hadPersistedDistinctId";

static NSString *const kDefaultKeySuiteName = @"Mixpanel";
static NSString *const kDefaultKeyPrefix = @"mixpanel";
static NSString *const kDefaultKeyOptOutStatus = @"OptOutStatus";
static NSString *const kDefaultKeyAutomaticEventEnabled = @"AutomaticEventEnabled";
static NSString *const kDefaultKeyAutomaticEventEnabledFromDecide = @"AutomaticEventEnabledFromDecide";
static NSString *const kDefaultKeyTimedEvents = @"timedEvents";
static NSString *const kDefaultKeySuperProperties = @"superProperties";
static NSString *const kDefaultKeyDistinctId = @"MPDistinctID";
static NSString *const kDefaultKeyPeopleDistinctId = @"MPPeopleDistinctID";
static NSString *const kDefaultKeyAnonymousId = @"MPAnonymousId";
static NSString *const kDefaultKeyUserId = @"MPUserId";
static NSString *const kDefaultKeyAlias = @"MPAlias";
static NSString *const kDefaultKeyHadPersistedDistinctId = @"MPHadPersistedDistinctId";


- (instancetype)initWithToken:(NSString *)token {
    self = [super init];
    if (self) {
        _apiToken = token;
        _mpdb = [[MPDB alloc] initWithToken:token];
    }
    return self;
}


- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type {
    [self saveEntity:entity type:type flag:NO];
}

- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type flag:(BOOL)flag {
    NSData *data = [MPJSONHandler encodedJSONData:entity];
    if (data) {
        [self.mpdb insertRow:type data:data flag:flag];
    }
}

- (void)saveEntities:(NSArray *)entities type:(NSString *)type flag:(BOOL)flag {
    for (NSDictionary *entity in entities) {
        [self saveEntity:entity type:type flag:flag];
    }
}

- (NSArray *)loadEntitiesInBatch:(NSString *)type {
    return [self loadEntitiesInBatch:type flag:NO];
}

- (NSArray *)loadEntitiesInBatch:(NSString *)type flag:(BOOL)flag {
    NSArray *entities = [self.mpdb readRows:type numRows:NSIntegerMax flag:flag];
    if ([type isEqualToString:PersistenceTypePeople]) {
        NSString *distinctId = [MixpanelPersistence loadIdentity:self.apiToken].distinctId;
        for (NSMutableDictionary *r in entities) {
            if (r[@"$distinct_id"] == nil && distinctId) {
                r[@"$distinct_id"] = distinctId;
            }
        }
    }
    return entities;
}

- (void)removeAutomaticEvents {
    NSArray *events = [self loadEntitiesInBatch:PersistenceTypeEvents];
    NSMutableArray *ids = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(NSMutableDictionary *event, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([event[@"event"] hasPrefix:@"$ae_"]) {
            [ids addObject:event[@"id"]];
        }
    }];
    if (ids.count > 0) {
        [self removeEntitiesInBatch:PersistenceTypeEvents ids:ids];
    }
}

- (void)removeEntitiesInBatch:(NSString *)type ids:(NSArray *)ids {
    [self.mpdb deleteRows:type ids:ids isDeleteAll:NO];
}

- (void)identifyPeople {
    [self.mpdb updateRowsFlag:PersistenceTypePeople newFlag:NO];
}

- (void)resetEntities {
    for (NSString *type in @[PersistenceTypeEvents, PersistenceTypePeople, PersistenceTypeGroups]) {
        [self.mpdb deleteRows:type ids:@[] isDeleteAll: YES];
    }
}

+ (void)saveOptOutStatusFlag:(BOOL)value apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        [defaults setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]];
        [defaults synchronize];
    }
}

+ (BOOL)optOutStatusNotSet:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        return ([defaults objectForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]] == nil);
    }
    return YES;
}

+ (BOOL)loadOptOutStatusFlagWithApiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        return [defaults boolForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyOptOutStatus]];
    }
    return NO;
}

+ (void)saveAutomaticEventsEnabledFlag:(BOOL)value fromDecide:(BOOL)fromDecide apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        if (fromDecide) {
            [defaults setBool:value forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabledFromDecide]];
        } else {
            [defaults setBool:value forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabled]];
        }
        [defaults synchronize];
    }
}

+ (BOOL)loadAutomaticEventsEnabledFlagWithApiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSString *automaticEventsEnabledKey = [NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabled];
        NSString *automaticEventsEnabledFromDecideKey = [NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAutomaticEventEnabledFromDecide];
        if ([defaults objectForKey:automaticEventsEnabledKey] == nil && [defaults objectForKey:automaticEventsEnabledFromDecideKey] == nil) {
            return YES; // default true
        }
        if ([defaults objectForKey:automaticEventsEnabledKey] != nil) {
            return [defaults boolForKey:automaticEventsEnabledKey];
        } else { // if there is no local settings, get the value from Decide
            return [defaults boolForKey:automaticEventsEnabledFromDecideKey];
        }
    }
    return YES;
}

+ (void)saveTimedEvents:(NSDictionary *)timedEvents apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *timedEventsData = [NSKeyedArchiver archivedDataWithRootObject:timedEvents];
        [defaults setValue:timedEventsData forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyTimedEvents]];
        [defaults synchronize];
    }
}

+ (NSDictionary *)loadTimedEvents:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *timedEventsData = [defaults dataForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyTimedEvents]];
        if (timedEventsData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:timedEventsData];
        }
    }
    return @{};
}

+ (void)saveSuperProperties:(NSDictionary *)superProperties apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *superPropertiesData = [NSKeyedArchiver archivedDataWithRootObject:superProperties];
        [defaults setValue:superPropertiesData forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeySuperProperties]];
        [defaults synchronize];
    }
}

+ (NSDictionary *)loadSuperProperties:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        NSData *superPropertiesData = [defaults dataForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeySuperProperties]];
        if (superPropertiesData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:superPropertiesData];
        }
    }
    return @{};
}

+ (void)saveIdentity:(MixpanelIdentity *)mixpanelIdentity apiToken:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    if (defaults) {
        NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
        [defaults setValue: mixpanelIdentity.distinctId forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyDistinctId]];
        [defaults setValue: mixpanelIdentity.peopleDistinctId forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyPeopleDistinctId]];
        [defaults setValue: mixpanelIdentity.anonymousId forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAnonymousId]];
        [defaults setValue: mixpanelIdentity.userId forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyUserId]];
        [defaults setValue: mixpanelIdentity.alias forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAlias]];
        [defaults setBool: mixpanelIdentity.hadPersistedDistinctId forKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyHadPersistedDistinctId]];
        [defaults synchronize];
    }
}

+ (MixpanelIdentity *)loadIdentity:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
    NSString *prefix = [NSString stringWithFormat:@"%@-%@", kDefaultKeyPrefix, apiToken];
    NSString *distinctId = [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyDistinctId]];
    NSString *peopleDistinctId = [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyPeopleDistinctId]];
    NSString *anonymousId = [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAnonymousId]];
    NSString *userId = [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyUserId]];
    NSString *alias = [defaults stringForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyAlias]];
    BOOL hadPersistedDistinctId = [defaults boolForKey:[NSString stringWithFormat:@"%@%@", prefix, kDefaultKeyHadPersistedDistinctId]];
    
    return [[MixpanelIdentity alloc] initWithDistinctId:distinctId peopleDistinctId:peopleDistinctId
                                                anonymousId:anonymousId userId:userId alias:alias hadPersistedDistinctId:hadPersistedDistinctId];
}

+ (void)deleteMPUserDefaultsData:(NSString *)apiToken {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultKeySuiteName];
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
    BOOL needMigration = [self needMigration];
    if (!needMigration) {
        return;
    }
    
    NSArray *eventsQueue = [self unarchiveEvents];
    NSArray *peopleQueue = [self unarchivePeople];
    NSArray *groupsQueue = [self unarchiveGroups];
    NSDictionary *properties = [self unarchiveProperties];
    NSNumber *optOutStatus = [self unarchiveOptOut];
    
    [self saveEntities:eventsQueue type:PersistenceTypeEvents flag:NO];
    [self saveEntities:peopleQueue type:PersistenceTypePeople flag:NO];
    [self saveEntities:groupsQueue type:PersistenceTypeGroups flag:NO];

    [MixpanelPersistence saveSuperProperties:properties[kLegacyDefaultKeySuperProperties] apiToken:self.apiToken];
    [MixpanelPersistence saveTimedEvents:properties[kLegacyDefaultKeyTimeEvents] apiToken:self.apiToken];
    [self saveEntities:properties[kLegacyDefaultKeyPeopleUnidentifiedQueue] type:PersistenceTypePeople flag:UnIdentifiedFlag];
    
    MixpanelIdentity *mixpanelIdentity = [[MixpanelIdentity alloc] initWithDistinctId:properties[kLegacyDefaultKeyDistinctId]
                                                                     peopleDistinctId:properties[kLegacyDefaultKeyPeopleDistinctId]
                                                                          anonymousId:properties[kLegacyDefaultKeyAnonymousId]
                                                                               userId:properties[kLegacyDefaultKeyUserId]
                                                                                alias:properties[kLegacyDefaultKeyAlias]
                                                               hadPersistedDistinctId:[properties[kLegacyDefaultKeyHadPersistedDistinctId] boolValue]];
    
    [MixpanelPersistence saveIdentity:mixpanelIdentity apiToken:self.apiToken];
    [MixpanelPersistence saveOptOutStatusFlag:[optOutStatus boolValue] apiToken:self.apiToken];
    NSNumber *automaticEventsFlag = properties[kLegacyDefaultKeyAutomaticEvents];
    if (automaticEventsFlag != nil) {
        [MixpanelPersistence saveAutomaticEventsEnabledFlag:[automaticEventsFlag boolValue] fromDecide:NO apiToken:self.apiToken];
    }
    [self removeLegacyFiles];
}

- (NSString *)filePathFor:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", self.apiToken, data];
#if !TARGET_OS_TV
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
}

- (NSString *)eventsFilePath
{
    return [self filePathFor:kLegacyArchiveTypeEvents];
}

- (NSString *)peopleFilePath
{
    return [self filePathFor:kLegacyArchiveTypePeople];
}

- (NSString *)groupsFilePath
{
    return [self filePathFor:kLegacyArchiveTypeGroups];
}

- (NSString *)propertiesFilePath
{
    return [self filePathFor:kLegacyArchiveTypeProperties];
}

- (NSString *)optOutFilePath
{
    return [self filePathFor:kLegacyArchiveTypeOptOutStatus];
}

- (void)removeArchivedFileAtPath:(NSString *)filePath
{
    NSError *error;
    [NSFileManager.defaultManager removeItemAtPath:filePath error:&error];
    if (error) {
        MPLogError(@"Unable to remove file at path: %@, error: %@", filePath, error);
    }
}

- (void)removeLegacyFiles
{
    [self removeArchivedFileAtPath:[self eventsFilePath]];
    [self removeArchivedFileAtPath:[self peopleFilePath]];
    [self removeArchivedFileAtPath:[self groupsFilePath]];
    [self removeArchivedFileAtPath:[self propertiesFilePath]];
    [self removeArchivedFileAtPath:[self optOutFilePath]];
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
            unarchivedData = [NSKeyedUnarchiver unarchivedObjectOfClasses:
                              [NSSet setWithArray:@[[NSArray class], [NSDictionary class], [NSSet class],
                                                    [NSString class], [NSDate class], [NSURL class],
                                                    [NSNumber class], [NSNull class]]]
                                                                 fromData:data error:&error];
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
    NSArray *events = (NSArray *)[MixpanelPersistence unarchiveOrDefaultFromFile:[self eventsFilePath] asClass:[NSArray class]];
    return events;
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

- (BOOL)needMigration
{
    NSFileManager *manager = [NSFileManager defaultManager];
    return [manager fileExistsAtPath:[self eventsFilePath]] ||
    [manager fileExistsAtPath:[self peopleFilePath]] ||
    [manager fileExistsAtPath:[self groupsFilePath]] ||
    [manager fileExistsAtPath:[self propertiesFilePath]] ||
    [manager fileExistsAtPath:[self optOutFilePath]];
}
@end
