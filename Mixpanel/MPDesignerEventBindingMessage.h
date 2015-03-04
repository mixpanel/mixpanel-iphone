//
//  MPDesignerEventBindingMessage.h
//  HelloMixpanel
//
//  Created by Amanda Canyon on 11/18/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPAbstractABTestDesignerMessage.h"

extern NSString *const MPDesignerEventBindingRequestMessageType;

@interface MPDesignerEventBindingRequestMesssage : MPAbstractABTestDesignerMessage

@end


@interface MPDesignerEventBindingResponseMesssage : MPAbstractABTestDesignerMessage

+ (instancetype)message;

@property (nonatomic, copy) NSString *status;

@end


@interface MPDesignerTrackMessage : MPAbstractABTestDesignerMessage

+ (instancetype)message;
+ (instancetype)messageWithPayload:(NSDictionary *)payload;

@end


