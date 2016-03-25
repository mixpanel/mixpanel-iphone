//
//  Mixpanel+CollectEverythingSerialization.h
//  Mixpanel
//
//  Created by Sam Green on 3/10/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Mixpanel/Mixpanel.h>

@interface Mixpanel (CollectEverythingSerialization)

+ (NSDictionary *)propertiesForDestination:(id)destination;
+ (NSDictionary *)propertiesForSource:(id)source;

+ (NSDictionary *)propertiesForSourceViewController:(UIViewController *)viewController;
+ (NSDictionary *)propertiesForDestinationViewController:(UIViewController *)viewController;

@end
