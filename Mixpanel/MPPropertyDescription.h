//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>

@class MPObjectSerializerContext;


@interface MPPropertyDescription : NSObject

- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSValueTransformer *)valueTransformer;

@property (nonatomic, readonly) NSString *type;

- (BOOL)shouldReadPropertyValueForObject:(NSObject *)object;

@property (nonatomic, readonly) BOOL readonly;
@property (nonatomic, readonly) NSString *name;


@end
