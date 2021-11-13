//
//  JSONHander.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPJSONHandler : NSObject

+ (NSString *)encodedJSONString:(id)data;
+ (NSData *)encodedJSONData:(id)data;

@end
