//
//  MPResources.m
//  Mixpanel
//
//  Created by Sam Green on 5/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPResources.h"

@implementation MPResources

+ (UIStoryboard *)notificationStoryboard {
    NSString *storyboardName = @"MPNotification~ipad";
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
        if (isLandscape) {
            storyboardName = @"MPNotification~iphonelandscape";
        } else {
            storyboardName = @"MPNotification~iphoneportrait";
        }
    }
    
    return [MPResources storyboardWithName:storyboardName];
}

+ (UIStoryboard *)surveyStoryboard {
    return [MPResources storyboardWithName:@"MPSurvey"];
}

+ (UIStoryboard *)storyboardWithName:(NSString *)name {
    return [UIStoryboard storyboardWithName:name bundle:[MPResources frameworkBundle]];
}

+ (NSBundle *)frameworkBundle {
    return [NSBundle bundleForClass:self.class];
}

@end
