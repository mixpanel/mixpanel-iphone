//
//  NSThread+MPHelpers.m
//  Mixpanel
//
//  Created by Peter Chien on 6/29/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "NSThread+MPHelpers.h"

@implementation NSThread (MPHelpers)

+ (void)mp_safelyRunOnMainThreadSync:(void (^)(void))block {
    if ([self isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@end
