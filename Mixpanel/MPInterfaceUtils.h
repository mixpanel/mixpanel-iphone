//
//  MPInterfaceUtils.h
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPInterfaceUtils : NSObject

+ (nullable UIViewController *)topPresentedViewController;
+ (BOOL)canPresentFromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
