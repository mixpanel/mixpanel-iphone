//
//  MPVariant.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPVariant : NSObject <NSCoding>

@property (nonatomic) NSUInteger ID;
@property (nonatomic) NSUInteger experimentID;
@property (nonatomic, strong) NSMutableArray *actions;

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object;

- (void) addActionsFromJSONObject:(NSArray *)actions andExecute:(BOOL)exec;
- (void) addActionFromJSONObject:(NSDictionary *)action andExecute:(BOOL)exec;
- (void)execute;
- (void)stop;

@end

@interface MPVariantAction : NSObject

@end
