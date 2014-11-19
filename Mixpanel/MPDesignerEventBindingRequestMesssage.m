//
//  MPDesignerEventBindingRequestMesssage.m
//  HelloMixpanel
//
//  Created by Amanda Canyon on 7/15/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "Mixpanel.h"
#import "MPSwizzler.h"
#import "MPObjectSelector.h"
#import "MPDesignerEventBindingMessage.h"
#import "MPABTestDesignerConnection.h"
#import "MPEventBinding.h"
#import "MPDesignerSessionCollection.h"

NSString *const MPDesignerEventBindingRequestMessageType = @"event_binding_request";

@interface MPEventBindingCollection : NSObject<MPDesignerSessionCollection>

@property (nonatomic) NSMutableArray *bindings;

@end

@implementation MPEventBindingCollection

- (void)updateBindings:(NSArray *)bindingPayload
{
    NSArray *oldBindings = self.bindings;
    NSMutableArray *newBindings = [NSMutableArray array];

    for (NSDictionary *bindingInfo in bindingPayload) {
        MPEventBinding *binding = [MPEventBinding bindngWithJSONObject:bindingInfo];
        [newBindings addObject:binding];
    }

    if (oldBindings) {
        [oldBindings makeObjectsPerformSelector:@selector(stop)];
    }
    self.bindings = newBindings;
    [newBindings makeObjectsPerformSelector:@selector(execute)];
}

- (void)cleanup
{
    [self.bindings makeObjectsPerformSelector:@selector(stop)];
    self.bindings = nil;
}

@end

@implementation MPDesignerEventBindingRequestMesssage

+ (instancetype)message
{
    return [[self alloc] initWithType:@"event_binding_request"];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        MPABTestDesignerConnection *conn = weak_connection;

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"Loading event bindings:\n%@",[[self payload] objectForKey:@"events"]);
            NSArray *payload = [[self payload] objectForKey:@"events"];
            MPEventBindingCollection *bindingCollection = [conn sessionObjectForKey:@"event_bindings"];
            if (!bindingCollection) {
                bindingCollection = [[MPEventBindingCollection alloc] init];
                [conn setSessionObject:bindingCollection forKey:@"event_bindings"];
            }
            [bindingCollection updateBindings:payload];
        });

        MPDesignerEventBindingResponseMesssage *changeResponseMessage = [MPDesignerEventBindingResponseMesssage message];
        changeResponseMessage.status = @"OK";
        [conn sendMessage:changeResponseMessage];
    }];

    return operation;
}

@end
