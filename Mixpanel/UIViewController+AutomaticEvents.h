//
//  UIViewController+AutomaticEvents.h
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (AutomaticEvents)

- (void)mp_viewDidAppear:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
