//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>
#import "MPWebSocket.h"

@protocol MPABTestDesignerMessage;

@interface MPABTestDesignerConnection : NSObject

- (id)initWithURL:(NSURL *)url;

@property (nonatomic, assign) BOOL connected;

- (void)sendMessage:(id<MPABTestDesignerMessage>)message;

@end
