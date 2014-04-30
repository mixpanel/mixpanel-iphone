//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@interface MPClassDescription : NSObject

- (id)initWithSuperclassDescription:(MPClassDescription *)superclassDescription dictionary:(NSDictionary *)dictionary;

@property (nonatomic, readonly) MPClassDescription *superclassDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray *propertyDescriptions;

- (BOOL)isDescriptionForKindOfClass:(Class)class;

@end
