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
#import "MPVariant.h"

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
        MPABTestDesignerConnection *connection = weak_connection;

        MPVariant *variant = [connection sessionObjectForKey:kSessionVariantKey];
        if (!variant) {
            variant = [[MPVariant alloc] init];
            [connection setSessionObject:variant forKey:kSessionVariantKey];
        }

        if ([[[self payload] objectForKey:@"tweaks"] isKindOfClass:[NSArray class]]) {
            NSLog(@"%@", [[self payload] objectForKey:@"tweaks"]);
            dispatch_sync(dispatch_get_main_queue(), ^{
                [variant addTweaksFromJSONObject:[[self payload] objectForKey:@"tweaks"] andExecute:YES];
            });
        }

        MPABTestDesignerTweakResponseMessage *changeResponseMessage = [MPABTestDesignerTweakResponseMessage message];
        changeResponseMessage.status = @"OK";
        [connection sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
