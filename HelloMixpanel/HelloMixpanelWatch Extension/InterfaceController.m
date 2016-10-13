//
//  InterfaceController.m
//  HelloMixpanelWatch Extension
//
//  Created by Peter Chien on 10/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

@import Mixpanel;

#import "InterfaceController.h"


@interface InterfaceController()

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (IBAction)tappedTrackButton {
    [[MixpanelWatchOS sharedInstance] track:@"tapped button"];
}

@end



