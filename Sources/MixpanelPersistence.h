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
#import "MixpanelIdentity.h"

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
- (void)resetEntities;
- (void)migrate;
+ (void)saveOptOutStatusFlag:(BOOL)value apiToken:(NSString *)apiToken;
+ (BOOL)loadOptOutStatusFlagWithApiToken:(NSString *)apiToken;
+ (BOOL)optOutStatusNotSet:(NSString *)apiToken;
+ (void)saveAutomaticEventsEnabledFlag:(BOOL)value fromDecide:(BOOL)fromDecide apiToken:(NSString *)apiToken;
+ (BOOL)loadAutomaticEventsEnabledFlagWithApiToken:(NSString *)apiToken;
+ (void)saveTimedEvents:(NSDictionary *)timedEvents apiToken:(NSString *)apiToken;
+ (NSDictionary *)loadTimedEvents:(NSString *)apiToken;
+ (void)saveSuperProperties:(NSDictionary *)superProperties apiToken:(NSString *)apiToken;
+ (NSDictionary *)loadSuperProperties:(NSString *)apiToken;
+ (void)saveIdentity:(MixpanelIdentity *)mixpanelIdentity apiToken:(NSString *)apiToken;
+ (MixpanelIdentity *)loadIdentity:(NSString *)apiToken;
+ (void)deleteMPUserDefaultsData:(NSString *)apiToken;


@end

#endif /* MixpanelPersistence_h */
