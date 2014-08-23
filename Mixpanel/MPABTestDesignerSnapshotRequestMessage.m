//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerSnapshotRequestMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPABTestDesignerSnapshotResponseMessage.h"
#import "MPApplicationStateSerializer.h"
#import "MPObjectSerializerConfig.h"
#import "MPObjectIdentityProvider.h"

NSString * const MPABTestDesignerSnapshotRequestMessageType = @"snapshot_request";

static NSString * const kSnapshotSerializerConfigKey = @"snapshot_class_descriptions";
static NSString * const kObjectIdentityProviderKey = @"object_identity_provider";

@implementation MPABTestDesignerSnapshotRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:MPABTestDesignerSnapshotRequestMessageType];
}

- (MPObjectSerializerConfig *)configuration
{
    NSDictionary *config =
#if 1
    [self payloadObjectForKey:@"config"];
#else
    [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"snapshot_config" withExtension:@"json"]]
                                    options:0 error:nil];
#endif

    return config ? [[MPObjectSerializerConfig alloc] initWithDictionary:config] : nil;
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __block MPObjectSerializerConfig *serializerConfig = self.configuration;
    __block NSString *imageHash = [self payloadObjectForKey:@"image_hash"];

    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MPABTestDesignerConnection *conn = weak_connection;

        // Update the class descriptions in the connection session if provided as part of the message.
        if (serializerConfig) {
            [connection setSessionObject:serializerConfig forKey:kSnapshotSerializerConfigKey];
        } else {
            // Get the class descriptions from the connection session store.
            serializerConfig = [connection sessionObjectForKey:kSnapshotSerializerConfigKey];
        }

        // Get the object identity provider from the connection's session store or create one if there is none already.
        MPObjectIdentityProvider *objectIdentityProvider = [connection sessionObjectForKey:kObjectIdentityProviderKey];
        if (objectIdentityProvider == nil) {
            objectIdentityProvider = [[MPObjectIdentityProvider alloc] init];
            [connection setSessionObject:objectIdentityProvider forKey:kObjectIdentityProviderKey];
        }

        MPApplicationStateSerializer *serializer = [[MPApplicationStateSerializer alloc] initWithApplication:[UIApplication sharedApplication]
                                                                                               configuration:serializerConfig
                                                                                      objectIdentityProvider:objectIdentityProvider];

        MPABTestDesignerSnapshotResponseMessage *snapshotMessage = [MPABTestDesignerSnapshotResponseMessage message];
        __block UIImage *screenshot = nil;
        __block NSDictionary *serializedObjects = nil;

        dispatch_sync(dispatch_get_main_queue(), ^{
            screenshot = [serializer screenshotImageForWindowAtIndex:0];
        });
        snapshotMessage.screenshot = screenshot;

        if (imageHash && [imageHash isEqualToString:snapshotMessage.imageHash]) {
            serializedObjects = [connection sessionObjectForKey:@"snapshot_hierarchy"];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                // TODO: we should probably be serializing an object graph from the UIApplication instance down and thus capturing all windows,
                // the keyWindow and all the relevant view controllers from the rootViewController of each window down.  Some applications
                // exist on multiple screens (apps that support HDMI output or AirPlay) and a screen can have multiple windows.  Eg, I think
                // UIAlertView exists in a separate window.  I think the status bar is also in a separate window.
                // For applications with multiple screens/windows this would mean capturing multiple screen shots too.
                serializedObjects = [serializer objectHierarchyForWindowAtIndex:0];
            });
            [connection setSessionObject:serializedObjects forKey:@"snapshot_hierarchy"];
        }

        snapshotMessage.serializedObjects = serializedObjects;
        [conn sendMessage:snapshotMessage];
    }];

    return operation;
}

@end
