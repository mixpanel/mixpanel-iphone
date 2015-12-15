//
//  ObjectSelector.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 5/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "MPObjectSelector.h"
#import "NSData+MPBase64.h"

@interface MPObjectFilter : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSPredicate *predicate;
@property (nonatomic, strong) NSNumber *index;
@property (nonatomic, assign) BOOL unique;
@property (nonatomic, assign) BOOL nameOnly;

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
    NSCharacterSet *_flagStartChar;
    NSCharacterSet *_flagEndChar;

}

@property (nonatomic, strong) NSScanner *scanner;
@property (nonatomic, strong) NSArray *filters;

@end

@implementation MPObjectSelector

+ (MPObjectSelector *)objectSelectorWithString:(NSString *)string
{
    return [[MPObjectSelector alloc] initWithString:string];
}

- (instancetype)initWithString:(NSString *)string
{
    if (self = [super init]) {
        _string = string;
        _scanner = [NSScanner scannerWithString:string];
        [_scanner setCharactersToBeSkipped:nil];
        _separatorChars = [NSCharacterSet characterSetWithCharactersInString:@"/"];
        _predicateStartChar = [NSCharacterSet characterSetWithCharactersInString:@"["];
        _predicateEndChar = [NSCharacterSet characterSetWithCharactersInString:@"]"];
        _classAndPropertyChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.*"];
        _flagStartChar = [NSCharacterSet characterSetWithCharactersInString:@"("];
        _flagEndChar = [NSCharacterSet characterSetWithCharactersInString:@")"];

        NSMutableArray *filters = [NSMutableArray array];
        MPObjectFilter *filter;
        while((filter = [self nextFilter])) {
            [filters addObject:filter];
        }
        self.filters = [filters copy];
    }
    return self;
}

/*
 Starting at the root object, try and find an object
 in the view/controller tree that matches this selector.
*/

- (NSArray *)selectFromRoot:(id)root
{
    return [self selectFromRoot:root evaluatingFinalPredicate:YES];
}

- (NSArray *)fuzzySelectFromRoot:(id)root
{
    return [self selectFromRoot:root evaluatingFinalPredicate:NO];
}

- (NSArray *)selectFromRoot:(id)root evaluatingFinalPredicate:(BOOL)finalPredicate
{
    NSArray *views = @[];
    if (root) {
        views = @[root];

        for (NSUInteger i = 0, n = [_filters count]; i < n; i++) {
            MPObjectFilter *filter = _filters[i];
            filter.nameOnly = (i == n-1 && !finalPredicate);
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
 by this selector starting from the root object given.
 */

- (BOOL)isLeafSelected:(id)leaf fromRoot:(id)root
{
    return [self isLeafSelected:leaf fromRoot:root evaluatingFinalPredicate:YES];
}

- (BOOL)fuzzyIsLeafSelected:(id)leaf fromRoot:(id)root
{
    return [self isLeafSelected:leaf fromRoot:root evaluatingFinalPredicate:NO];
}

- (BOOL)isLeafSelected:(id)leaf fromRoot:(id)root evaluatingFinalPredicate:(BOOL)finalPredicate
{
    BOOL isSelected = YES;
    NSArray *views = @[leaf];
    NSUInteger n = [_filters count], i = n;
    while(i--) {
        MPObjectFilter *filter = _filters[i];
        filter.nameOnly = (i == n-1 && !finalPredicate);
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
        if ([_scanner scanCharactersFromSet:_flagStartChar intoString:nil]) {
            NSString *flags;
            [_scanner scanUpToCharactersFromSet:_flagEndChar intoString:&flags];
            for (NSString *flag in[flags componentsSeparatedByString:@"|"]) {
                if ([flag isEqualToString:@"unique"]) {
                    filter.unique = YES;
                }
            }
        }
        if ([_scanner scanCharactersFromSet:_predicateStartChar intoString:nil]) {
            NSString *predicateFormat;
            NSInteger index = 0;
            if ([_scanner scanInteger:&index] && [_scanner scanCharactersFromSet:_predicateEndChar intoString:nil]) {
                filter.index = @((NSUInteger)index);
            } else {
                [_scanner scanUpToCharactersFromSet:_predicateEndChar intoString:&predicateFormat];
                @try {
                    NSPredicate *parsedPredicate = [NSPredicate predicateWithFormat:predicateFormat];
                    filter.predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
                        @try {
                            return [parsedPredicate evaluateWithObject:evaluatedObject substitutionVariables:bindings];
                        }
                        @catch (NSException *exception) {
                            return false;
                        }
                    }];
                }
                @catch (NSException *exception) {
                    filter.predicate = [NSPredicate predicateWithValue:NO];
                }

                [_scanner scanCharactersFromSet:_predicateEndChar intoString:nil];
            }
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

- (instancetype)init
{
    if((self = [super init])) {
        self.unique = NO;
        self.nameOnly = NO;
    }
    return self;
}

/*
 Apply this filter to the views, returning all of their children
 that match this filter's class / predicate pattern
 */
- (NSArray *)apply:(NSArray *)views
{
    NSMutableArray *result = [NSMutableArray array];

    Class class = NSClassFromString(_name);
    if (class || [_name isEqualToString:@"*"]) {
        // Select all children
        for (NSObject *view in views) {
            NSArray *children = [self getChildrenOfObject:view ofType:class];
            if (_index && [_index unsignedIntegerValue] < [children count]) {
                // Indexing can only be used for subviews of UIView
                if ([view isKindOfClass:[UIView class]]) {
                    children = @[children[[_index unsignedIntegerValue]]];
                } else {
                    children = @[];
                }
            }
            [result addObjectsFromArray:children];
        }
    }

    if (!self.nameOnly) {
        // If unique is set and there are more than one, return nothing
        if(self.unique && [result count] != 1) {
            return @[];
        }
        // Filter any resulting views by predicate
        if (self.predicate) {
            return [result filteredArrayUsingPredicate:self.predicate];
        }
    }
    return [result copy];
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
    return (([self.name isEqualToString:@"*"] || [view isKindOfClass:NSClassFromString(self.name)])
            && (self.nameOnly || (
                (!self.predicate || [_predicate evaluateWithObject:view])
                && (!self.index || [self isView:view siblingNumber:[_index integerValue]])
                && (!(self.unique) || [self isView:view oneOfNSiblings:1])))
            );
}

/*
 Returns whether any of the given views would pass this filter
 */
- (BOOL)appliesToAny:(NSArray *)views
{
    for (NSObject *view in views) {
        if ([self appliesTo:view]) {
            return YES;
        }
    }
    return NO;
}

/*
 Returns true if the given view is at the index given by number in
 its parent's subviews. The view's parent must be of type UIView
 */

- (BOOL)isView:(NSObject *)view siblingNumber:(NSInteger)number
{
    return [self isView:view siblingNumber:number of:-1];
}

- (BOOL)isView:(NSObject *)view oneOfNSiblings:(NSInteger)number
{
    return [self isView:view siblingNumber:-1 of:number];
}

- (BOOL)isView:(NSObject *)view siblingNumber:(NSInteger)index of:(NSInteger)numSiblings
{
    NSArray *parents = [self getParentsOfObject:view];
    for (NSObject *parent in parents) {
        if ([parent isKindOfClass:[UIView class]]) {
            NSArray *siblings = [self getChildrenOfObject:parent ofType:NSClassFromString(_name)];
            if ((index < 0 || ((NSUInteger)index < [siblings count] && siblings[(NSUInteger)index] == view))
                && (numSiblings < 0 || [siblings count] == (NSUInteger)numSiblings)) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSArray *)getParentsOfObject:(NSObject *)obj
{
    NSMutableArray *result = [NSMutableArray array];
    if ([obj isKindOfClass:[UIView class]]) {
        UIView *superview = [(UIView *)obj superview];
        if (superview) {
            [result addObject:superview];
        }
        UIResponder *nextResponder = [(UIView *)obj nextResponder];
        // For UIView, nextResponder should be its controller or its superview.
        if (nextResponder && nextResponder != superview) {
            [result addObject:nextResponder];
        }
    } else if ([obj isKindOfClass:[UIViewController class]]) {
        UIViewController *parentViewController = [(UIViewController *)obj parentViewController];
        if (parentViewController) {
            [result addObject:parentViewController];
        }
        UIViewController *presentingViewController = [(UIViewController *)obj presentingViewController];
        if (presentingViewController) {
            [result addObject:presentingViewController];
        }
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow.rootViewController == obj) {
            //TODO is there a better way to get the actual window that has this VC
            [result addObject:keyWindow];
        }
    }
    return [result copy];
}

- (NSArray *)getChildrenOfObject:(NSObject *)obj ofType:(Class)class
{
    NSMutableArray *children = [NSMutableArray array];
    // A UIWindow is also a UIView, so we could in theory follow the subviews chain from UIWindow, but
    // for now we only follow rootViewController from UIView.
    if ([obj isKindOfClass:[UIWindow class]]) {
        UIViewController *rootViewController = ((UIWindow *)obj).rootViewController;
        if ([rootViewController isKindOfClass:class]) {
            [children addObject:rootViewController];
        }
    } else if ([obj isKindOfClass:[UIView class]]) {
        // NB. For UIViews, only add subviews, nothing else.
        // The ordering of this result is critical to being able to
        // apply the index filter.
        for (NSObject *child in [(UIView *)obj subviews]) {
            if (!class || [child isKindOfClass:class]) {
                [children addObject:child];
            }
        }
    } else if ([obj isKindOfClass:[UIViewController class]]) {
        UIViewController *viewController = (UIViewController *)obj;
        for (NSObject *child in [viewController childViewControllers]) {
            if (!class || [child isKindOfClass:class]) {
                [children addObject:child];
            }
        }
        UIViewController *presentedViewController = viewController.presentedViewController;
        if (presentedViewController && (!class || [presentedViewController isKindOfClass:class])) {
            [children addObject:presentedViewController];
        }
        if (!class || (viewController.isViewLoaded && [viewController.view isKindOfClass:class])) {
            [children addObject:viewController.view];
        }
    }
    NSArray *result;
    // Reorder the cells in a table view so that they are arranged by y position
    if ([class isSubclassOfClass:[UITableViewCell class]]) {
        result = [children sortedArrayUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
            if (obj2.frame.origin.y > obj1.frame.origin.y) {
                return NSOrderedAscending;
            } else if (obj2.frame.origin.y < obj1.frame.origin.y) {
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        }];
    } else {
        result = [children copy];
    }
    return result;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"%@[%@]", self.name, self.index ?: self.predicate];
}

@end
