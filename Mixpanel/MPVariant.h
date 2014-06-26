//
//  MPVariant.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPVariant : NSObject

@property (nonatomic, strong) NSMutableArray *actions;

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object;

- (void) addActions:(NSArray *)actions andExecute:(BOOL)exec;
- (void) addAction:(NSDictionary *)action andExecute:(BOOL)exec;
- (void)execute;

@end
