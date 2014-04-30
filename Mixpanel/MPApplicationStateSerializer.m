//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPApplicationStateSerializer.h"
#import "MPObjectSerializer.h"
#import "MPClassDescription.h"

@implementation MPApplicationStateSerializer
{
    MPObjectSerializer *_serializer;
    UIApplication *_application;
}

- (id)initWithApplication:(UIApplication *)application
{
    self = [super init];
    if (self)
    {
        _application = application;

        #pragma message("TODO: WIP this should be supplied via constructor param (and loaded from network).")
        NSURL *classDefinitionsURL = [[NSBundle mainBundle] URLForResource:@"ClassDefinitions" withExtension:@"json"];
        NSError *error = nil;
        NSData *classDefinitionsData = [NSData dataWithContentsOfURL:classDefinitionsURL options:NSDataReadingMappedIfSafe error:&error];
        if (classDefinitionsData)
        {
            NSDictionary *classDefinitions = [NSJSONSerialization JSONObjectWithData:classDefinitionsData options:0 error:&error];
            NSAssert([classDefinitions isKindOfClass:[NSDictionary class]] && [classDefinitions objectForKey:@"classes"] != nil, @"Expected dictionary with classes element!");

            NSMutableDictionary *classDescriptions = [[NSMutableDictionary alloc] init];
            for (NSDictionary *dictionary in classDefinitions[@"classes"])
            {
                NSString *superclassName = dictionary[@"superclass"];
                MPClassDescription *superclassDescription = superclassName ? classDescriptions[superclassName] : nil;
                MPClassDescription *classDescription = [[MPClassDescription alloc] initWithSuperclassDescription:superclassDescription
                                                                                                      dictionary:dictionary];
                
                [classDescriptions setObject:classDescription forKey:classDescription.name];
            }

            _serializer = [[MPObjectSerializer alloc] initWithClassDescriptions:[classDescriptions allValues]];
        }
        else
        {
            NSLog(@"Error reading class definitions: %@", error);
        }
    }

    return self;
}

- (UIImage *)screenshotImageForWindowAtIndex:(NSUInteger)index
{
    UIImage *image = nil;

    UIWindow *window = [self windowAtIndex:index];
    if (window)
    {
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, window.screen.scale);
        if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES] == NO)
        {
            NSLog(@"Unable to get complete screenshot for window at index: %d.", (int)index);
        }
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    return image;
}

- (UIWindow *)windowAtIndex:(NSUInteger)index
{
    NSParameterAssert(index < [_application.windows count]);
    return _application.windows[index];
}

- (NSDictionary *)viewControllerHierarchyForWindowAtIndex:(NSUInteger)index
{

    UIWindow *window = [self windowAtIndex:index];
    if (window)
    {
        return [_serializer serializedObjectsWithRootObject:window.rootViewController];
    }

    return @{};
}

@end
