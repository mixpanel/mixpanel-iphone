//
//  MPUITableViewBinding.h
//  HelloMixpanel
//
//  Created by Amanda Canyon on 8/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPEventBinding.h"

@interface MPUITableViewBinding : MPEventBinding

- (instancetype)init __unavailable;
- (instancetype)initWithEventName:(NSString *)eventName onPath:(NSString *)path withDelegate:(Class)delegateClass;

@end
