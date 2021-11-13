//
//  MPConnectIntegrations.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "Mixpanel.h"

@interface MPConnectIntegrations : NSObject

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel;
- (void)reset;
- (void)setupIntegrations:(NSArray<NSString *> *)integrations;

@end
