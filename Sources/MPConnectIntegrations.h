//
//  MPConnectIntegrations.h
//  Mixpanel
//
//  Created by Peter Chien on 10/9/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"

@interface MPConnectIntegrations : NSObject

- (instancetype)initWithMixpanel:(Mixpanel *)mixpanel;
- (void)reset;
- (void)setupIntegrations:(NSArray<NSString *> *)integrations;

@end
