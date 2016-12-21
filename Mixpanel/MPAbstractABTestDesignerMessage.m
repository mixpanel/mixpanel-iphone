//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPAbstractABTestDesignerMessage.h"
#import "MPLogger.h"

@interface MPAbstractABTestDesignerMessage ()

@property (nonatomic, copy, readwrite) NSString *type;

@end

@implementation MPAbstractABTestDesignerMessage

{
    NSMutableDictionary *_payload;
}

+ (instancetype)messageWithType:(NSString *)type payload:(NSDictionary *)payload
{
    return [(MPAbstractABTestDesignerMessage *)[self alloc] initWithType:type payload:payload];
}

- (instancetype)initWithType:(NSString *)type
{
    return [self initWithType:type payload:@{}];
}

- (instancetype)initWithType:(NSString *)type payload:(NSDictionary *)payload
{
    self = [super init];
    if (self) {
        _type = type;
        _payload = [payload mutableCopy];
    }

    return self;
}

- (void)setPayloadObject:(id)object forKey:(NSString *)key
{
    _payload[key] = object ?: [NSNull null];
}

- (id)payloadObjectForKey:(NSString *)key
{
    id object = _payload[key];
    return [object isEqual:[NSNull null]] ? nil : object;
}

- (NSDictionary *)payload
{
    return [_payload copy];
}

- (NSData *)JSONData
{
    NSDictionary *jsonObject = @{ @"type": _type, @"payload": [_payload copy] };

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:(NSJSONWritingOptions)0 error:&error];
    if (error) {
        MPLogError(@"Failed to serialize test designer message: %@", error);
    }

    return jsonData;
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    return nil;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@:%p type='%@'>", NSStringFromClass([self class]), (__bridge void *)self, self.type];
}

@end
