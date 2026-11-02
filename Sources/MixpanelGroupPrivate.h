//
//  MixpanelGroupPrivate.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//
#import "MixpanelType.h"

@class Mixpanel;

@interface MixpanelGroup ()

@property (nonatomic, weak) Mixpanel *mixpanel;
@property (nonatomic, copy) NSString *groupKey;
@property (nonatomic, copy) id<MixpanelType> groupID;

- (instancetype)init:(Mixpanel *)mixpanel groupKey:(NSString*)groupKey groupID:(id<MixpanelType>)groupID;

@end

// A group with nothing to update, from getCompany when there is no company. Every method drops
// the update with an error log.
@interface MixpanelUnavailableGroup : MixpanelGroup

- (instancetype)initWithReason:(NSString *)reason;

@end
