//
//  MixpanelPeoplePrivate.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//
#import <Foundation/Foundation.h>

@class Mixpanel;

@interface MixpanelPeople ()

@property (nonatomic, weak) Mixpanel *mixpanel;
@property (nonatomic, copy) NSString *distinctId;
@property (nonatomic, strong) NSDictionary *automaticPeopleProperties;

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel;
- (void)merge:(NSDictionary *)properties;
// Hierarchical groups only. Must run on the Mixpanel serial queue.
- (void)saveHierarchicalGroupsRecordWithAction:(NSString *)action properties:(NSDictionary *)properties time:(NSNumber *)epochMilliseconds;

@end
