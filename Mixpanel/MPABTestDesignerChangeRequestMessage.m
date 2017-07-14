//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerChangeRequestMessage.h"
#import "MPABTestDesignerChangeResponseMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "MPVariant.h"

NSString *const MPABTestDesignerChangeRequestMessageType = @"change_request";

@implementation MPABTestDesignerChangeRequestMessage

+ (instancetype)message
{
    return [(MPABTestDesignerChangeRequestMessage *)[self alloc] initWithType:MPABTestDesignerChangeRequestMessageType];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        MPVariant *variant = [connection sessionObjectForKey:kSessionVariantKey];
        if (!variant) {
            variant = [[MPVariant alloc] init];
            [connection setSessionObject:variant forKey:kSessionVariantKey];
        }

        id actions = [self payload][@"actions"];
        if ([actions isKindOfClass:[NSArray class]]) {
            [variant addActionsFromJSONObject:actions andExecute:YES];
        }

        MPABTestDesignerChangeResponseMessage *changeResponseMessage = [MPABTestDesignerChangeResponseMessage message];
        changeResponseMessage.status = @"OK";
        [conn sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
