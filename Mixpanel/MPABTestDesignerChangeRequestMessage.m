//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerChangeRequestMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "MPABTestDesignerChangeResponseMessage.h"
#import "MPVariant.h"

NSString *const MPABTestDesignerChangeRequestMessageType = @"change_request";

@implementation MPABTestDesignerChangeRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"change_request"];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        dispatch_sync(dispatch_get_main_queue(), ^{
            MPVariant *variant = [MPVariant variantWithJSONObject:[self payload]];
            [variant execute];
        });

        MPABTestDesignerChangeResponseMessage *changeResponseMessage = [MPABTestDesignerChangeResponseMessage message];
        changeResponseMessage.status = @"OK";
        [conn sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
