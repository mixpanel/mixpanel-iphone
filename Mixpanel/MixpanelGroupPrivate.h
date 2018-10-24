//
//  MixpanelGroupPrivate.h
//  Mixpanel
//
//  Created by Weizhe Yuan on 8/21/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//
#import <MixpanelType.h>

@class Mixpanel;

@interface MixpanelGroup ()

@property (nonatomic, weak) Mixpanel *mixpanel;
@property (nonatomic, copy) NSString *groupKey;
@property (nonatomic, copy) id<MixpanelType> groupID;

- (instancetype)init:(Mixpanel *)mixpanel groupKey:(NSString*)groupKey groupID:(id<MixpanelType>)groupID;

@end
