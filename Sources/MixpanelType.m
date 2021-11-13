//
//  MPValue.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "MixpanelType.h"
#import <Foundation/Foundation.h>

@implementation NSString (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    return [mixpanelType isKindOfClass:[NSString class]] && [self isEqual:mixpanelType];
}

@end

@implementation NSNumber (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    return [mixpanelType isKindOfClass:[NSNumber class]] && [self isEqual:mixpanelType];
}

@end

@implementation NSDate (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    return [mixpanelType isKindOfClass:[NSDate class]] && [self isEqual:mixpanelType];
}

@end

@implementation NSURL (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    return [mixpanelType isKindOfClass:[NSURL class]] && [self isEqual:mixpanelType];
}

@end

@implementation NSArray (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    if (![mixpanelType isKindOfClass:[NSArray class]]) {
        return NO;
    }
    
    NSArray *mixpanelTypeArray = (NSArray *)mixpanelType;
    if ([self count] != [mixpanelTypeArray count]) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < [self count]; ++i) {
        id<MixpanelType> v1 = (id<MixpanelType>)self[i];
        id<MixpanelType> v2 = (id<MixpanelType>)mixpanelTypeArray[i];
        if ([v1 class] != [v2 class] || ![v1 conformsToProtocol:@protocol(MixpanelType)] ||
            ![v1 equalToMixpanelType:v2]) {
            return NO;
        }
    }
    
    return YES;
}

@end

@implementation NSDictionary (MixpanelTypeCategory)

- (BOOL)equalToMixpanelType:(id<MixpanelType>)mixpanelType
{
    if (![mixpanelType isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    NSDictionary *mixpanelType_ = (NSDictionary *)mixpanelType;
    if ([self count] != [mixpanelType_ count]) {
        return NO;
    }
    
    __block BOOL ret = YES;
    [self enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value1, BOOL *stop) {
        NSObject *value2 = [mixpanelType_ objectForKey:key];
        id<MixpanelType> v1 = (id<MixpanelType>)value1;
        id<MixpanelType> v2 = (id<MixpanelType>)value2;
        if ([v1 class] != [v2 class] || ![v1 conformsToProtocol:@protocol(MixpanelType)] || ![v1 equalToMixpanelType:v2]) {
            *stop = YES;
            ret = NO;
        }
    }];
    
    return ret;
}

@end
