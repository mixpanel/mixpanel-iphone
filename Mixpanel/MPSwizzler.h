//
//  MPSwizzler.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPSwizzler : NSObject

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(void (^)(id))block;
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass;

@end
