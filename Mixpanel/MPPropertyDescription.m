//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPPropertyDescription.h"
#import "MPObjectSerializerContext.h"

@interface MPPropertyDescription ()
@property (nonatomic, readonly) NSPredicate *predicate;
@end

@implementation MPPropertyDescription

+ (NSValueTransformer *)valueTransformerForType:(NSString *)typeName
{
    // TODO: lookup transformer by type

    for (NSString *toTypeName in @[@"NSDictionary", @"NSNumber", @"NSString"])
    {
        NSString *toTransformerName = [NSString stringWithFormat:@"MP%@To%@ValueTransformer", typeName, toTypeName];
        NSValueTransformer *toTransformer = [NSValueTransformer valueTransformerForName:toTransformerName];
        if (toTransformer)
        {
            return toTransformer;
        }
    }

    // Default to pass-through.
    return [NSValueTransformer valueTransformerForName:@"MPPassThroughValueTransformer"];
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self)
    {
        _name = [dictionary[@"name"] copy];
        _type = [dictionary[@"type"] copy];
        _readonly = [dictionary[@"readonly"] boolValue];

        NSString *predicateFormat = dictionary[@"predicate"];
        if (predicateFormat)
        {
            _predicate = [NSPredicate predicateWithFormat:predicateFormat];
        }
    }

    return self;
}

- (NSValueTransformer *)valueTransformer
{
    return [[self class] valueTransformerForType:self.type];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@:%p name='%@' type='%@' %@>", NSStringFromClass([self class]), (__bridge void *)self, self.name, self.type, self.readonly ? @"readonly" : @""];
}

- (BOOL)shouldReadPropertyValueForObject:(NSObject *)object
{
    if (_predicate)
    {
        return [_predicate evaluateWithObject:object];
    }

    return YES;
}

@end
