//
//  Mixpanel+CollectEverythingSerialization.m
//  Mixpanel
//
//  Created by Sam Green on 3/10/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel+CollectEverythingSerialization.h"
#import "CollectEverythingConstants.h"
#import "MPLogger.h"
#import <objc/runtime.h>

@implementation Mixpanel (CollectEverythingSerialization)

+ (NSDictionary *)propertiesForSource:(id)source {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    if ([source respondsToSelector:@selector(class)]) {
        properties[kSourceClassKey] = NSStringFromClass([source class]);
        
        NSString *text = [self textForElement:source];
        if (text) {
            properties[kSourceTextKey] = text;
        }
        
        if ([source respondsToSelector:@selector(accessibilityIdentifier)]) {
            properties[kSourceAccessibilityIdentifierKey] = [source accessibilityIdentifier];
        }
        if ([source respondsToSelector:@selector(accessibilityLabel)]) {
            properties[kSourceAccessibilityLabelKey] = [source accessibilityLabel];
        }
        
        UIViewController *sourceViewController = [source isKindOfClass:UIViewController.class] ? source : [self viewControllerContainingView:source];
        if (sourceViewController) {
            NSString *name = [self nameForInstanceVariable:source inObject:sourceViewController];
            if (name) {
                properties[kSourceNameKey] = name;
            }
            
            [properties addEntriesFromDictionary:[self propertiesForSourceViewController:sourceViewController]];
        }
    }
    return [properties copy];
}

+ (NSDictionary *)propertiesForDestination:(id)destination {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    if ([destination respondsToSelector:@selector(class)]) {
        properties[kDestinationClassKey] = NSStringFromClass([destination class]);
        
        // Text
        NSString *text = [self textForElement:destination];
        if (text) {
            properties[kDestinationTextKey] = text;
        }
        
        if ([destination respondsToSelector:@selector(accessibilityIdentifier)]) {
            properties[kDestinationAccessibilityIdentifierKey] = [destination accessibilityIdentifier];
        }
        if ([destination respondsToSelector:@selector(accessibilityLabel)]) {
            properties[kDestinationAccessibilityLabelKey] = [destination accessibilityLabel];
        }
        
        
        UIViewController *destinationViewController = [destination isKindOfClass:UIViewController.class] ? destination : [self viewControllerContainingView:destination];
        if (destinationViewController) {
            NSString *name = [self nameForInstanceVariable:destination inObject:destinationViewController];
            if (name) {
                properties[kDestinationNameKey] = name;
            }
            
            [properties addEntriesFromDictionary:[self propertiesForDestinationViewController:destinationViewController]];
        }
    }
    return [properties copy];
}

+ (NSDictionary *)propertiesForSourceViewController:(UIViewController *)viewController {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    properties[kSourceViewControllerClassKey] = NSStringFromClass(viewController.class);
    
    if (viewController.title) {
        properties[kSourceViewControllerTitleKey] = viewController.title;
    }
    
    if (viewController.accessibilityLabel) {
        properties[kSourceViewControllerAccessibilityLabelKey] = viewController.accessibilityLabel;
    }
    
    return [properties copy];
}

+ (NSDictionary *)propertiesForDestinationViewController:(UIViewController *)viewController {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    properties[kDestinationViewControllerClassKey] = NSStringFromClass(viewController.class);
    
    if (viewController.title) {
        properties[kDestinationViewControllerTitleKey] = viewController.title;
    }
    
    if (viewController.accessibilityLabel) {
        properties[kDestinationViewControllerAccessibilityLabelKey] = viewController.accessibilityLabel;
    }
    
    return [properties copy];
}

#pragma mark - Helpers
+ (NSString *)nameForInstanceVariable:(id)instanceVariable inObject:(NSObject *)object {
    NSString *name = nil;
    
    uint count;
    Ivar *ivars = class_copyIvarList([object class], &count);
    for (uint i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        if (ivar_getTypeEncoding(ivar)[0] == '@' && object_getIvar(object, ivar) == self) {
            name = [NSString stringWithCString:ivar_getName(ivar) encoding:NSUTF8StringEncoding];
            break;
        }
    }
    free(ivars);
    
    return name;
}

+ (UIViewController *)viewControllerContainingView:(id)view {
    SEL viewControllerSelector = NSSelectorFromString(@"viewController");
    if ([view respondsToSelector:viewControllerSelector]) {
        return [view performSelector:viewControllerSelector];
    }
    
    if ([view respondsToSelector:@selector(nextResponder)]) {
        id responder = [view nextResponder];
        while (responder != nil) {
            if ([responder isKindOfClass:UIViewController.class]) {
                return (UIViewController *)responder;
            }
            responder = [responder nextResponder];
        }
    }
    return nil;
}

+ (NSString *)textForElement:(id)element {
    if ([element isKindOfClass:UILabel.class]) {
        return [element text];
    } else if ([element respondsToSelector:@selector(titleForState:)]) {
        return [element titleForState:UIControlStateNormal];
    } else if ([element respondsToSelector:@selector(titleLabel)]) {
        return [[element titleLabel] text];
    } else if ([element respondsToSelector:@selector(title)]) {
        if ([[element title] isKindOfClass:NSString.class]) {
            return [element title];
        }
    }
    return nil;
}

@end
