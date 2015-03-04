//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>
#import "MPTypeDescription.h"

@interface MPClassDescription : MPTypeDescription

@property (nonatomic, readonly) MPClassDescription *superclassDescription;
@property (nonatomic, readonly) NSArray *propertyDescriptions;
@property (nonatomic, readonly) NSArray *delegateInfos;

- (id)initWithSuperclassDescription:(MPClassDescription *)superclassDescription dictionary:(NSDictionary *)dictionary;

- (BOOL)isDescriptionForKindOfClass:(Class)class;

@end

@interface MPDelegateInfo : NSObject

@property (nonatomic, readonly) NSString *selectorName;

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
