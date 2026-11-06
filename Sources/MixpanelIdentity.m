//
//  MixpanelIdentity.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelIdentity.h"
#import "MixpanelPrivate.h"


@implementation MixpanelIdentity

- (instancetype)initWithUserId:(NSString *)userId companyId:(NSString *)companyId
{
    self = [super init];
    if (self) {
        _userId = [userId copy];
        _companyId = [companyId copy];
    }
    return self;
}

- (instancetype)initWithUserId:(NSString *)userId companyId:(NSString *)companyId deviceId:(NSString *)deviceId
{
    self = [self initWithUserId:userId companyId:companyId];
    if (self) {
        _deviceId = [deviceId copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // immutable
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[MixpanelIdentity class]]) {
        return NO;
    }
    MixpanelIdentity *other = (MixpanelIdentity *)object;
    return (self.userId == other.userId || [self.userId isEqualToString:other.userId]) &&
           (self.companyId == other.companyId || [self.companyId isEqualToString:other.companyId]) &&
           (self.deviceId == other.deviceId || [self.deviceId isEqualToString:other.deviceId]);
}

- (NSUInteger)hash
{
    NSUInteger result = self.userId.hash;
    result = 31 * result + self.companyId.hash;
    result = 31 * result + self.deviceId.hash;
    return result;
}

- (NSString *)description
{
    NSMutableArray *fields = [NSMutableArray array];
    if (self.userId) {
        [fields addObject:[NSString stringWithFormat:@"userId=%@", self.userId]];
    }
    if (self.companyId) {
        [fields addObject:[NSString stringWithFormat:@"companyId=%@", self.companyId]];
    }
    if (self.deviceId) {
        [fields addObject:[NSString stringWithFormat:@"deviceId=%@", self.deviceId]];
    }
    return [NSString stringWithFormat:@"MixpanelIdentity(%@)", [fields componentsJoinedByString:@", "]];
}

@end
