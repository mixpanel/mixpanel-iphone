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
        _classAndPropertyChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.*"];

    }
    return self;
}

-(id)selectFromRoot:(NSObject *)root
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
        } else {
            filter.name = @"*";
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

    if ([_name isEqualToString:@"*"]) {
        // Select all children
        for (NSObject *view in views) {
            [result addObjectsFromArray:[self getChildrenOfObject:view ofType:nil]];
        }
    } else {
        if ([_name hasPrefix:@"."]) {
            // Select children by property name on parent
            NSString *key = [_name substringFromIndex:1];
            @try {
                for (NSObject *view in views) {
                    NSObject *value = [view valueForKey:key];
                    if (value) {
                        [result addObject:value];
                    }
                }
            }
            @catch (NSException *exception) {}
        } else {
            // Select all children of a given class
            Class class = NSClassFromString(_name);
            if (class) {
                for (NSObject *view in views) {
                    [result addObjectsFromArray:[self getChildrenOfObject:view ofType:class]];
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

-(NSArray *)getChildrenOfObject:(NSObject *)obj ofType:(Class)class
{
    NSMutableArray *result = [NSMutableArray array];
    if ([obj isKindOfClass:[UIView class]]) {
        for (NSObject *child in [(UIView *)obj subviews]) {
            if (!class || [child isKindOfClass:class]) {
                [result addObject:child];
            }
        }
    } else if ([obj isKindOfClass:[UIViewController class]]) {
        for (NSObject *child in [(UIViewController *)obj childViewControllers]) {
            if (!class || [child isKindOfClass:class]) {
                [result addObject:child];
            }
        }
        [result addObject:((UIViewController *)obj).view];
    }
    return [result copy];
}

@end
