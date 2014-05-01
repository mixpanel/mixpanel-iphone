//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerChangesMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerSnapshotMessage.h"


@implementation MPABTestDesignerChangesMessage

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        // TODO: apply changes

        __block UIImage *screenshot = nil;
        __block NSDictionary *serializedObjects = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            // TODO: snapshot UI state
        });

        MPABTestDesignerSnapshotMessage *snapshotMessage = [MPABTestDesignerSnapshotMessage message];
        snapshotMessage.screenshot = screenshot;
        snapshotMessage.serializedObjects = serializedObjects;
        [conn sendMessage:snapshotMessage];
    }];

    return operation;
}

@end
