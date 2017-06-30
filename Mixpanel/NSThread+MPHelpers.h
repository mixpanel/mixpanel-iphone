//
//  NSThread+MPHelpers.h
//  Mixpanel
//
//  Created by Peter Chien on 6/29/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSThread (MPHelpers)

+ (void)mp_safelyRunOnMainThreadSync:(void (^)(void))block;

@end
