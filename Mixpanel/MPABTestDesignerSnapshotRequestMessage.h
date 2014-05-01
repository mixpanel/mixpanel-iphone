//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import <Foundation/Foundation.h>
#import "MPAbstractABTestDesignerMessage.h"

extern NSString *const MPABTestDesignerSnapshotRequestMessageType;

@interface MPABTestDesignerSnapshotRequestMessage : MPAbstractABTestDesignerMessage

+ (instancetype)message;

@property (nonatomic, readonly) NSDictionary *configuration;

@end
