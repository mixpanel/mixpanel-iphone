//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPEnumDescription.h"

@implementation MPEnumDescription

{
    NSMutableDictionary *_values;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    NSParameterAssert(dictionary[@"flag_set"] != nil);
    NSParameterAssert(dictionary[@"base_type"] != nil);
    NSParameterAssert(dictionary[@"values"] != nil);

    self = [super initWithDictionary:dictionary];
    if (self) {
        _flagSet = [dictionary[@"flag_set"] boolValue];
        _baseType = [dictionary[@"base_type"] copy];
        _values = [NSMutableDictionary dictionary];

        for (NSDictionary *value in dictionary[@"values"]) {
            _values[value[@"value"]] = value[@"display_name"];
        }
    }

    return self;
}

- (NSArray *)allValues
{
    return _values.allKeys;
}

@end
