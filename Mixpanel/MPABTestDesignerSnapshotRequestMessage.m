//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerSnapshotRequestMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerSnapshotMessage.h"
#import "MPApplicationStateSerializer.h"

@implementation MPABTestDesignerSnapshotRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"snapshot_request"];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MPABTestDesignerConnection *conn = weak_connection;

        __block UIImage *screenshot = nil;
        __block NSDictionary *serializedObjects = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{

            // FIXME: We probably shouldn't be initializing this every time.
            MPApplicationStateSerializer *serializer = [[MPApplicationStateSerializer alloc] initWithApplication:[UIApplication sharedApplication]];
            screenshot = [serializer screenshotImageForWindowAtIndex:0];
            serializedObjects = [serializer viewControllerHierarchyForWindowAtIndex:0];

        });

        MPABTestDesignerSnapshotMessage *snapshotMessage = [MPABTestDesignerSnapshotMessage message];
        snapshotMessage.screenshot = screenshot;
        snapshotMessage.serializedObjects = serializedObjects;
        [conn sendMessage:snapshotMessage];
    }];

    return operation;
}

@end
