//
//  Mixpanel+AutomaticEvents.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"

@interface Mixpanel (AutomaticEvents)

+ (instancetype)sharedAutomatedInstance;
+ (void)setSharedAutomatedInstance:(Mixpanel *)instance;

@end
