//
//  MPPersistence.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPPersistence : NSObject

- (instancetype)initWithToken:(NSString *)token;

#pragma mark - Archive
- (void)archiveEvents:(NSMutableArray *)events;
- (void)archivePeople:(NSMutableArray *)people;
- (void)archiveProperties:(NSMutableDictionary *)properties;
- (void)archiveVariants:(NSSet *)variants;
- (void)archiveEventBindings:(NSSet *)eventBindings;

#pragma mark - Unarchive
- (NSMutableArray *)unarchiveEvents;
- (NSMutableArray *)unarchivePeople;
- (NSMutableDictionary *)unarchiveProperties;
- (NSSet *)unarchiveVariants;
- (NSSet *)unarchiveEventBindings;

@end
