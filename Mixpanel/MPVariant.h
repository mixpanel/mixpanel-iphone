//
//  MPVariant.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPVariant : NSObject

@property (nonatomic, strong) NSArray *actions;

+ (MPVariant *)variantWithDummyJSONObject;
+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object;

- (void)execute;

@end
