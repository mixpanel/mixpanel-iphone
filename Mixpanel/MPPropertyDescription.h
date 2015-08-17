//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@class MPObjectSerializerContext;

@interface MPPropertySelectorParameterDescription : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *type;

@end

@interface MPPropertySelectorDescription : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) NSString *selectorName;
@property (nonatomic, readonly) NSString *returnType;
@property (nonatomic, readonly) NSArray *parameters; // array of MPPropertySelectorParameterDescription

@end

@interface MPPropertyDescription : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) BOOL readonly;
@property (nonatomic, readonly) BOOL nofollow;
@property (nonatomic, readonly) BOOL useKeyValueCoding;
@property (nonatomic, readonly) BOOL useInstanceVariableAccess;
@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) MPPropertySelectorDescription *getSelectorDescription;
@property (nonatomic, readonly) MPPropertySelectorDescription *setSelectorDescription;

- (BOOL)shouldReadPropertyValueForObject:(NSObject *)object;

- (NSValueTransformer *)valueTransformer;

@end
