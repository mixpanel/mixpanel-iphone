//
//  MPResources.m
//  Mixpanel
//
//  Created by Sam Green on 5/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPResources.h"
#import "MixpanelPrivate.h"

@implementation MPResources

+ (UIStoryboard *)storyboardWithName:(NSString *)name {
    return [UIStoryboard storyboardWithName:name bundle:[MPResources frameworkBundle]];
}

+ (NSBundle *)frameworkBundle {
    return [NSBundle bundleForClass:self.class];
}

+ (NSString *)notificationXibName {
    NSMutableString *xibFileName = [NSMutableString stringWithString:@"MPTakeoverNotificationViewController"];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        UIApplication *sharedApplication = [Mixpanel sharedUIApplication];
        BOOL isLandscape = UIInterfaceOrientationIsLandscape(sharedApplication.statusBarOrientation);
        if (isLandscape) {
            [xibFileName appendString:@"~iphonelandscape"];
        } else {
            [xibFileName appendString:@"~iphoneportrait"];
        }
    } else {
        [xibFileName appendString:@"~ipad"];
    }
    
    return [xibFileName copy];
}

+ (UIImage *)imageNamed:(NSString *)name {
    NSString *imagePath = [[MPResources frameworkBundle] pathForResource:name ofType:@"png"];
    return [UIImage imageWithContentsOfFile:imagePath];
}

@end
