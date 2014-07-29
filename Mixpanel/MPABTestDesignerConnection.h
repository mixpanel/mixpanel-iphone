//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>
#import "MPWebSocket.h"

@protocol MPABTestDesignerMessage;

extern NSString *const kSessionVariantKey;

@interface MPABTestDesignerConnection : NSObject

- (id)initWithURL:(NSURL *)url;

- (void)setSessionObject:(id)object forKey:(NSString *)key;
- (id)sessionObjectForKey:(NSString *)key;

@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL sessionEnded;

- (void)sendMessage:(id<MPABTestDesignerMessage>)message;

@end
