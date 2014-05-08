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

// Facebook Tweaks
#import "FBTweakStore.h"
#import "FBTweakCollection.h"
#import "FBTweakCategory.h"
#import "FBTweak.h"

NSString *const MPABTestDesignerTweakRequestMessageType = @"tweak_request";

@implementation MPABTestDesignerTweakRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"tweak_request"];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSArray *tweaks = [self payload][@"tweaks"];
            for (NSDictionary *tweak in tweaks) {
                FBTweakStore *store = [FBTweakStore sharedInstance];
                FBTweakCategory *category = [store tweakCategoryWithName:tweak[@"category"]];
                FBTweakCollection *collection = [category tweakCollectionWithName:tweak[@"collection"]];
                FBTweak *fbTweak = [collection tweakWithIdentifier:tweak[@"identifier"]];

                NSLog(@"%@", tweak[@"value"]);
                fbTweak.currentValue = tweak[@"value"];
            }

        });

        MPABTestDesignerTweakResponseMessage *changeResponseMessage = [MPABTestDesignerTweakResponseMessage message];
        changeResponseMessage.status = @"OK";
        [conn sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
