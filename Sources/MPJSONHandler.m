//
//  JSONHandler.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPLogger.h"
#import "MPJSONHander.h"

@implementation MPJSONHandler : NSObject

+ (NSString *)encodedJSONString:(id)data {
    NSData *jsonData = [self encodedJSONData:data];
    return jsonData ? [[NSString alloc] initWithData:jsonData
                                                   encoding:NSUTF8StringEncoding] : @"";
}

+ (NSData *)encodedJSONData:(id)data {
    NSError *error = NULL;
    NSData *jsonData = nil;
    @try {
        jsonData = [NSJSONSerialization dataWithJSONObject:[self convertFoundationTypesToJSON:data]
                                               options:(NSJSONWritingOptions)0
                                                 error:&error];
    }
    @catch (NSException *exception) {
        MPLogError(@"exception encoding api data: %@", exception);
    }
    
    if (error) {
        MPLogError(@"error encoding api data: %@", error);
    }
    
    return jsonData;
}


+ (id)convertFoundationTypesToJSON:(id)obj {
    // check if the NSString is a valid UTF-8 string
    if ([obj isKindOfClass:NSString.class]) {
        obj = (NSString *)obj;
        if ([obj UTF8String] == nil) {
            // not a valid UTF-8 string
            // we will use the replacement char '\uFFFD' to prevent nil and crash
            obj = @"\ufffd";
            MPLogWarning(@"property value got invalid UTF-8 string");
        }
        return obj;
    }
    // valid json types
    if ([obj isKindOfClass:NSNumber.class] || [obj isKindOfClass:NSNull.class]) {
        return obj;
    }
    
    if ([obj isKindOfClass:NSDate.class]) {
        return [[self dateFormatter] stringFromDate:obj];
    } else if ([obj isKindOfClass:NSURL.class]) {
        return [obj absoluteString];
    }
    
    // recurse on containers
    if ([obj isKindOfClass:NSArray.class]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self convertFoundationTypesToJSON:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey = key;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                MPLogWarning(@"%@ property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            }
            id v = [self convertFoundationTypesToJSON:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    
    // default to sending the object's description
    NSString *s = [obj description];
    MPLogWarning(@"%@ property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return formatter;
}

@end
