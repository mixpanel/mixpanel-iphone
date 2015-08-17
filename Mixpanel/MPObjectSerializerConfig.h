//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@class MPEnumDescription;
@class MPClassDescription;
@class MPTypeDescription;


@interface MPObjectSerializerConfig : NSObject

@property (nonatomic, readonly) NSArray *classDescriptions;
@property (nonatomic, readonly) NSArray *enumDescriptions;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (MPTypeDescription *)typeWithName:(NSString *)name;
- (MPEnumDescription *)enumWithName:(NSString *)name;
- (MPClassDescription *)classWithName:(NSString *)name;

@end
