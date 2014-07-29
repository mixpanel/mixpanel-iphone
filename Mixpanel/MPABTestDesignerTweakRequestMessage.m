//
//  MPABTestDesignerTweakRequestMessage.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 7/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPABTestDesignerTweakRequestMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerTweakResponseMessage.h"

// Mixpanel Tweaks
#import "MPTweakStore.h"
#import "MPTweak.h"

NSString *const MPABTestDesignerTweakRequestMessageType = @"tweak_request";

@implementation MPABTestDesignerTweakRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:MPABTestDesignerTweakRequestMessageType];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSArray *tweaks = [self payload][@"tweaks"];
            for (NSDictionary *tweak in tweaks) {
                MPTweakStore *store = [MPTweakStore sharedInstance];
                MPTweak *mpTweak = [store tweakWithName:tweak[@"tweak"]];

                mpTweak.currentValue = tweak[@"value"];
            }
        });

        MPABTestDesignerTweakResponseMessage *changeResponseMessage = [MPABTestDesignerTweakResponseMessage message];
        changeResponseMessage.status = @"OK";
        [conn sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
