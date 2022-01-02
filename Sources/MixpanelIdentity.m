//
//  MixpanelIdentity.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelIdentity.h"


@interface MixpanelIdentity()

@property (nonatomic, readwrite, copy) NSString *distinctId;
@property (nonatomic, readwrite, copy) NSString *peopleDistinctId;
@property (nonatomic, readwrite, copy) NSString *anonymousId;
@property (nonatomic, readwrite, copy) NSString *userId;
@property (nonatomic, readwrite, copy) NSString *alias;

@end

@implementation MixpanelIdentity

- (instancetype)initWithDistinctId:(NSString *)distinctId
                  peopleDistinctId:(NSString *)peopleDistinctId
                       anonymousId:(NSString *)anonymousId
                            userId:(NSString *)userId
                             alias:(NSString *)alias
            hadPersistedDistinctId:(BOOL)hadPersistedDistinctId
{
    self = [super init];
    if (self) {
        self.distinctId = distinctId;
        self.peopleDistinctId = peopleDistinctId;
        self.anonymousId = anonymousId;
        self.userId = userId;
        self.alias = alias;
        self.hadPersistedDistinctId = hadPersistedDistinctId;
    }
    return self;
}

@end
