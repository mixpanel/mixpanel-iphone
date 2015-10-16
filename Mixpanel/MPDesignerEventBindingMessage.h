//
//  MPDesignerEventBindingMessage.h
//  HelloMixpanel
//
//  Created by Amanda Canyon on 11/18/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "MPAbstractABTestDesignerMessage.h"

extern NSString *const MPDesignerEventBindingRequestMessageType;

@interface MPDesignerEventBindingRequestMessage : MPAbstractABTestDesignerMessage

@end

__deprecated
@interface MPDesignerEventBindingRequestMesssage : MPDesignerEventBindingRequestMessage

@end


@interface MPDesignerEventBindingResponseMessage : MPAbstractABTestDesignerMessage

+ (instancetype)message;

@property (nonatomic, copy) NSString *status;

@end

__deprecated
@interface MPDesignerEventBindingResponseMesssage : MPDesignerEventBindingResponseMessage

@end


@interface MPDesignerTrackMessage : MPAbstractABTestDesignerMessage

+ (instancetype)message;
+ (instancetype)messageWithPayload:(NSDictionary *)payload;

@end


