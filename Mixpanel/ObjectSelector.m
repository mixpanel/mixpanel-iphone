//
//  ObjectSelector.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 5/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "ObjectSelector.h"


@interface ObjectFilter : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSPredicate *predicate;

- (NSArray *)apply:(NSArray *)views;

@end

@interface ObjectSelector () {
    NSCharacterSet *_classAndPropertyChars;
    NSCharacterSet *_separatorChars;
    NSCharacterSet *_predicateStartChar;
    NSCharacterSet *_predicateEndChar;
}

@property (nonatomic, strong) NSScanner *scanner;

@end


@implementation ObjectSelector

-(id) initWithString:(NSString *)string
{
    if (self = [super init]) {
        self.scanner = [[NSScanner alloc] initWithString:string];
        [_scanner setCharactersToBeSkipped:nil];
        _separatorChars = [NSCharacterSet characterSetWithCharactersInString:@"/"];
        _predicateStartChar = [NSCharacterSet characterSetWithCharactersInString:@"["];
        _predicateEndChar = [NSCharacterSet characterSetWithCharactersInString:@"]"];
        _classAndPropertyChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."];

    }
    return self;
}

-(id)selectFromRoot:(UIView *)root
{
    NSArray *views = @[root];
    ObjectFilter *filter = [self nextFilter];

    do {
        views = [filter apply:views];
        filter = [self nextFilter];
    } while (filter && [views count] > 0);
    return views;
}

- (ObjectFilter *)nextFilter
{
    ObjectFilter *filter;
    if ([_scanner scanCharactersFromSet:_separatorChars intoString:nil]) {
        NSString *name;
        filter = [[ObjectFilter alloc] init];
        if ([_scanner scanCharactersFromSet:_classAndPropertyChars intoString:&name]) {
            filter.name = name;
        }
        if ([_scanner scanCharactersFromSet:_predicateStartChar intoString:nil]) {
            NSString *predicateFormat;
            [_scanner scanUpToCharactersFromSet:_predicateEndChar intoString:&predicateFormat];
            filter.predicate = [NSPredicate predicateWithFormat:predicateFormat];
            [_scanner scanCharactersFromSet:_predicateEndChar intoString:nil];
        }
    }
    return filter;
}

@end

@implementation ObjectFilter

- (NSArray *)apply:(NSArray *)views
{
    NSMutableArray *result = [NSMutableArray array];

    // Select subviews by class (or property of superview).
    if (!_name) {
        // By default include all subviews, if no class or property is specified.
        for (NSObject *view in views) {
            [result addObjectsFromArray:[self getSubviewsOfView:view ofType:[UIView class]]];
        }
    } else {
        if ([_name hasPrefix:@"."]) {
            NSString *key = [_name substringFromIndex:1];
            @try {
                for (NSObject *view in views) {
                    NSObject *value = [view valueForKey:key];
                    if (value) {
                        [result addObject:value];
                    }
                }
            }
            @catch (NSException *exception) {} //object does not know about this key
        } else {
            Class class = NSClassFromString(_name);
            if (class) {
                for (NSObject *view in views) {
                    [result addObjectsFromArray:[self getSubviewsOfView:view ofType:class]];
                }
            }
        }
    }

    // Filter any resulting views by predicate
    if (_predicate) {
        return [result filteredArrayUsingPredicate:_predicate];
    } else {
        return [result copy];
    }
}

-(NSArray *)getSubviewsOfView:(NSObject *)view ofType:(Class)class
{
    NSMutableArray *result = [NSMutableArray array];
    if ([view isKindOfClass:[UIView class]]) {
        for (UIView *subview in [(UIView *)(view) subviews]) {
            if ([subview isKindOfClass:class]) {
                [result addObject:subview];
            }
        }
    }
    return result;
}

@end
