//
//  MixpanelPersistence.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#ifndef MixpanelPersistence_h
#define MixpanelPersistence_h

#import <Foundation/Foundation.h>
#import "MPDB.h"

// The identity state archived per token. Distinct from the public MixpanelIdentity.
@interface MixpanelPersistedIdentity : NSObject

@property (nonatomic, readonly, copy) NSString *distinctId;
@property (nonatomic, readonly, copy) NSString *peopleDistinctId;
@property (nonatomic, readonly, copy) NSString *anonymousId;
@property (nonatomic, readonly, copy) NSString *userId;
@property (nonatomic, readonly, copy) NSString *companyId;
@property (nonatomic, readonly, copy) NSString *alias;
@property (nonatomic, assign) BOOL hadPersistedDistinctId;

- (instancetype)initWithDistinctId:(NSString *)distinctId
                  peopleDistinctId:(NSString *)peopleDistinctId
                       anonymousId:(NSString *)anonymousId
                            userId:(NSString *)userId
                         companyId:(NSString *)companyId
                             alias:(NSString *)alias
            hadPersistedDistinctId:(BOOL)hadPersistedDistinctId;

@end

@interface MixpanelPersistence : NSObject

@property (nonatomic, readonly, copy) NSString *apiToken;

- (instancetype)initWithToken:(NSString *)token;
- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type;
- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type flag:(BOOL)flag;
- (void)saveEntities:(NSArray *)entities type:(NSString *)type flag:(BOOL)flag;

- (NSArray *)loadEntitiesInBatch:(NSString *)type;
- (NSArray *)loadEntitiesInBatch:(NSString *)type flag:(BOOL)flag;
- (void)removeAutomaticEvents;
- (void)removeEntitiesInBatch:(NSString *)type ids:(NSArray *)ids;
- (void)identifyPeople;
- (void)identifyHierarchicalGroupsPeopleWithUserId:(NSString *)userId companyId:(NSString *)companyId;
- (void)resetEntities;
- (void)migrate;
+ (void)saveOptOutStatusFlag:(BOOL)value apiToken:(NSString *)apiToken;
+ (BOOL)loadOptOutStatusFlagWithApiToken:(NSString *)apiToken;
+ (BOOL)optOutStatusNotSet:(NSString *)apiToken;
+ (void)saveTimedEvents:(NSDictionary *)timedEvents apiToken:(NSString *)apiToken;
+ (NSDictionary *)loadTimedEvents:(NSString *)apiToken;
+ (void)saveSuperProperties:(NSDictionary *)superProperties apiToken:(NSString *)apiToken;
+ (NSDictionary *)loadSuperProperties:(NSString *)apiToken;
+ (void)saveIdentity:(MixpanelPersistedIdentity *)mixpanelIdentity apiToken:(NSString *)apiToken;
+ (MixpanelPersistedIdentity *)loadIdentity:(NSString *)apiToken;
+ (void)deleteMPUserDefaultsData:(NSString *)apiToken;


@end

#endif /* MixpanelPersistence_h */
