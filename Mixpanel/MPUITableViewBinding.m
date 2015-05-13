//
//  MPUITableViewBinding.m
//  HelloMixpanel
//
//  Created by Amanda Canyon on 8/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "MPSwizzler.h"
#import "MPUITableViewBinding.h"

@implementation MPUITableViewBinding

+ (NSString *)typeName
{
    return @"ui_table_view";
}

+ (MPEventBinding *)bindngWithJSONObject:(NSDictionary *)object
{
    NSString *path = [object objectForKey:@"path"];
    if (![path isKindOfClass:[NSString class]] || [path length] < 1) {
        NSLog(@"must supply a view path to bind by");
        return nil;
    }

    NSString *eventName = [object objectForKey:@"event_name"];
    if (![eventName isKindOfClass:[NSString class]] || [eventName length] < 1 ) {
        NSLog(@"binding requires an event name");
        return nil;
    }

    Class tableDelegate = NSClassFromString(object[@"table_delegate"]);
    if (!tableDelegate) {
        NSLog(@"binding requires a table_delegate class");
        return nil;
    }

    return [[MPUITableViewBinding alloc] initWithEventName:eventName
                                                  onPath:path
                                            withDelegate:tableDelegate];
}

- (id)initWithEventName:(NSString *)eventName onPath:(NSString *)path
{
    return [self initWithEventName:eventName onPath:path withDelegate:nil];
}

- (instancetype)initWithEventName:(NSString *)eventName onPath:(NSString *)path withDelegate:(Class)delegateClass
{
    if (self = [super initWithEventName:eventName onPath:path]) {
        [self setSwizzleClass:delegateClass];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"UITableView Event Tracking: '%@' for '%@'", [self eventName], [self path]];
}


#pragma mark -- Executing Actions

- (void)execute
{
    if (!self.running && self.swizzleClass != nil) {
        NSObject *root = [[UIApplication sharedApplication] keyWindow].rootViewController;
        void (^block)(id, SEL, id, id) = ^(id view, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
            // select targets based off path
            if (tableView && [self.path isLeafSelected:tableView fromRoot:root]) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                NSString *label = (cell && cell.textLabel && cell.textLabel.text) ? cell.textLabel.text : @"";
                [[self class] track:[self eventName]
                                      properties:@{
                                                   @"Cell Index": [NSString stringWithFormat: @"%ld", (unsigned long)indexPath.row],
                                                   @"Cell Section": [NSString stringWithFormat: @"%ld", (unsigned long)indexPath.section],
                                                   @"Cell Label": label
                                                }];
            }
        };

        [MPSwizzler swizzleSelector:@selector(tableView:didSelectRowAtIndexPath:)
                            onClass:self.swizzleClass
                          withBlock:block
                              named:self.name];
        self.running = true;
    }
}

- (void)stop
{
    if (self.running && self.swizzleClass != nil) {
        [MPSwizzler unswizzleSelector:@selector(tableView:didSelectRowAtIndexPath:)
                              onClass:self.swizzleClass
                                named:self.name];
        self.running = false;
    }
}

#pragma mark -- Helper Methods

- (UITableView *)parentTableView:(UIView *)cell {
    // iterate up the view hierarchy to find the table containing this cell/view
    UIView *aView = cell.superview;
    while(aView != nil) {
        if([aView isKindOfClass:[UITableView class]]) {
            return (UITableView *)aView;
        }
        aView = aView.superview;
    }
    return nil; // this view is not within a tableView
}

@end
