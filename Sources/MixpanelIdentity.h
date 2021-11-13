//
//  MixpanelIdentity.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MixpanelIdentity : NSObject

@property (nonatomic, readonly, copy) NSString *distinctId;
@property (nonatomic, readonly, copy) NSString *peopleDistinctId;
@property (nonatomic, readonly, copy) NSString *anonymousId;
@property (nonatomic, readonly, copy) NSString *userId;
@property (nonatomic, readonly, copy) NSString *alias;
@property (nonatomic, assign) BOOL hadPersistedDistinctId;


- (instancetype)initWithDistinctId:(NSString *)distinctId
                  peopleDistinctId:(NSString *)peopleDistinctId
                       anonymousId:(NSString *)anonymousId
                            userId:(NSString *)userId
                             alias:(NSString *)alias
            hadPersistedDistinctId:(BOOL)hadPersistedDistinctId;

@end
