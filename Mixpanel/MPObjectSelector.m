//
//  ObjectSelector.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 5/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPObjectSelector.h"


@interface MPObjectFilter : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSPredicate *predicate;

- (NSArray *)apply:(NSArray *)views;
- (NSArray *)applyReverse:(NSArray *)views;
- (BOOL)appliesTo:(NSObject *)view;
- (BOOL)appliesToAny:(NSArray *)views;

@end

@interface MPObjectSelector () {
    NSCharacterSet *_classAndPropertyChars;
    NSCharacterSet *_separatorChars;
    NSCharacterSet *_predicateStartChar;
    NSCharacterSet *_predicateEndChar;
}

@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSScanner *scanner;
@property (nonatomic, strong) NSArray *filters;

@end


@implementation MPObjectSelector

+ (MPObjectSelector *)objectSelectorWithString:(NSString *)string
{
    return [[MPObjectSelector alloc] initWithString:string];
}

-(id) initWithString:(NSString *)string
{
    if (self = [super init]) {
        self.string = string;
        self.scanner = [[NSScanner alloc] initWithString:string];
        [_scanner setCharactersToBeSkipped:nil];
        _separatorChars = [NSCharacterSet characterSetWithCharactersInString:@"/"];
        _predicateStartChar = [NSCharacterSet characterSetWithCharactersInString:@"["];
        _predicateEndChar = [NSCharacterSet characterSetWithCharactersInString:@"]"];
        _classAndPropertyChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.*"];

        MPObjectFilter *filter;
        NSMutableArray *filters = [NSMutableArray array];
        while((filter = [self nextFilter])) {
            [filters addObject:filter];
        }
        self.filters = [filters copy];
    }
    return self;
}

/*
 Starting at the root object, try and find an object
 in the view/controller tree that matches this selector
*/
-(NSArray *)selectFromRoot:(id)root
{
    NSArray *views = @[];
    if (root) {
        views = @[root];

        for (MPObjectFilter *filter in _filters) {
            views = [filter apply:views];
            if ([views count] == 0) {
                break;
            }
        }
    }
    return views;
}

/*
 Starting at a leaf node, determine if it would be selected
 by this selector starting from the root
*/

-(BOOL)isLeafSelected:(id)leaf fromRoot:(id)root
{
    BOOL isSelected = YES;
    NSArray *views = @[leaf];
    NSUInteger i = [_filters count];
    while(i--) {
        MPObjectFilter *filter = _filters[i];
        if (![filter appliesToAny:views]) {
            isSelected = NO;
            break;
        }
        views = [filter applyReverse:views];
        if ([views count] == 0) {
            break;
        }
    }
    return isSelected && [views indexOfObject:root] != NSNotFound;
}

- (MPObjectFilter *)nextFilter
{
    MPObjectFilter *filter;
    if ([_scanner scanCharactersFromSet:_separatorChars intoString:nil]) {
        NSString *name;
        filter = [[MPObjectFilter alloc] init];
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

- (Class)selectedClass
{
    if ([_filters count] > 0) {
        return NSClassFromString(((MPObjectFilter *)_filters[[_filters count] - 1]).name);
    }
    return nil;
}

- (NSString *)description
{
    return self.string;
}

@end

@implementation MPObjectFilter

/*
 Apply this filter to the views, returning all of their chhildren
 that match this filter's class / predicate pattern
 */
- (NSArray *)apply:(NSArray *)views
{
    NSMutableArray *result = [NSMutableArray array];

    if ([_name isEqualToString:@"*"]) {
        // Select all children
        for (NSObject *view in views) {
            [result addObjectsFromArray:[self getChildrenOfObject:view ofType:nil]];
        }
    } else {
        // Select all children of a given class
        Class class = NSClassFromString(_name);
        if (class) {
            for (NSObject *view in views) {
                [result addObjectsFromArray:[self getChildrenOfObject:view ofType:class]];
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

/*
 Apply this filter to the views. For any view that
 matches this filter's class / predicate pattern, return
 its parents.
 */
- (NSArray *)applyReverse:(NSArray *)views
{
    NSMutableArray *result = [NSMutableArray array];
    for (NSObject *view in views) {
        if ([self appliesTo:view]) {
            [result addObjectsFromArray:[self getParentsOfObject:view]];
        }
    }
    return [result copy];
}

/*
 Returns whether the given view would pass this filter.
*/
- (BOOL)appliesTo:(NSObject *)view
{
    return([_name isEqualToString:@"*"] || [view isKindOfClass:NSClassFromString(_name)]) && (!_predicate || [_predicate evaluateWithObject:view]);
}

- (BOOL)appliesToAny:(NSArray *)views
{
    for (NSObject *view in views) {
        if ([self appliesTo:view]) {
            return YES;
        }
    }
    return NO;
}

-(NSArray *)getParentsOfObject:(NSObject *)obj
{
    NSMutableArray *result = [NSMutableArray array];
    if ([obj isKindOfClass:[UIView class]]) {
        if ([(UIView *)obj superview]) {
            [result addObject:[(UIView *)obj superview]];
        }
        // For UIView, nextResponder should be its controller or its superview.
        if ([(UIView *)obj nextResponder] && [(UIView *)obj nextResponder] != [(UIView *)obj superview]) {
            [result addObject:[(UIView *)obj nextResponder]];
        }
    } else if ([obj isKindOfClass:[UIViewController class]]) {
        if ([(UIViewController *)obj parentViewController]) {
            [result addObject:[(UIViewController *)obj parentViewController]];
        }
        if ([(UIViewController *)obj presentingViewController]) {
            [result addObject:[(UIViewController *)obj presentingViewController]];
        }
        if ([UIApplication sharedApplication].keyWindow.rootViewController == obj) {
            [result addObject:[UIApplication sharedApplication].keyWindow];
        }
    }
    return [result copy];
}

-(NSArray *)getChildrenOfObject:(NSObject *)obj ofType:(Class)class
{
    NSMutableArray *result = [NSMutableArray array];
    // A UIWindow is also a UIView, so we could in theory follow the subviews chain from UIWindow, but
    // for now we only follow rootViewController from UIView.
    if ([obj isKindOfClass:[UIWindow class]] && [((UIWindow *)obj).rootViewController isKindOfClass:class]) {
        [result addObject:((UIWindow *)obj).rootViewController];
    } else if ([obj isKindOfClass:[UIView class]]) {
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
        if (((UIViewController *)obj).presentedViewController && (!class || [((UIViewController *)obj).presentedViewController isKindOfClass:class])) {
            [result addObject:((UIViewController *)obj).presentedViewController];
        }
        if (!class || [((UIViewController *)obj).view isKindOfClass:class]) {
            [result addObject:((UIViewController *)obj).view];
        }
    }
    return [result copy];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"%@[%@]", self.name, self.predicate];
}

@end
