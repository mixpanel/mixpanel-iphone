//
//  MixpanelPersistence.h
//  Mixpanel
//
//  Created by Jared McFarland on 10/1/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#ifndef MixpanelPersistence_h
#define MixpanelPersistence_h

#import <Foundation/Foundation.h>
#import "MPDB.h"

@interface MixpanelPersistence : NSObject {
    NSString *_apiToken;
    MPDB *_mpdb;
}

@property (nonatomic, copy) NSString *apiToken;
@property (nonatomic, copy) MPDB *mpdb;

- (instancetype)initWithToken:(NSString *)token;
- (void)saveEntity:(NSDictionary *)entity type:(NSString *)type flag:(bool)flag;
- (void)saveEntities:(NSArray *)entities type:(NSString *)type flag:(bool)flag;
- (NSArray *)loadEntitiesInBatch:(NSString *)type batchSize:(int)batchSize flag:(bool)flag;
- (void)removeEntitiesInBatch:(NSString *)type ids:(NSArray *)ids;
- (void)identifyPeople;
- (void) resetEntities;
- (void)migrate;
- (bool)needMigration;

+ (void) saveOptOutStatusFlag:(bool)value apiToken:(NSString *)apiToken;
+ (bool) loadOptOutStatusFlag:(NSString *)apiToken;
+ (void) saveAutomaticEventsEnabledFlag:(bool)value fromDecide:(bool)fromDecide apiToken:(NSString *)apiToken;
+ (bool) loadAutomaticEventsEnabledFlag:(NSString *)apiToken;
+ (void) saveTimedEvents:(NSDictionary *)timedEvents apiToken:(NSString *)apiToken;
+ (NSDictionary *) loadTimedEvents:(NSString *)apiToken;
+ (void) saveSuperProperties:(NSDictionary *)superProperties apiToken:(NSString *)apiToken;
+ (NSDictionary *) loadSuperProperties:(NSString *)apiToken;
+ (void) saveIdentity:(NSDictionary *)mixpanelIdentity apiToken:(NSString *)apiToken;
+ (NSDictionary *) loadIdentity:(NSString *)apiToken;
+ (void) deleteMPUserDefaultsData:(NSString *)apiToken;

@end

#endif /* MixpanelPersistence_h */
