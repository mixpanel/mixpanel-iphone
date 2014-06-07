//
//  MPSwizzler.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 1/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^swizzleBlock)();

@interface MPSwizzler : NSObject

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)block;
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass;

@end
