//
//  JSONHander.h
//  Mixpanel
//
//  Created by ZIHE JIA on 10/26/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPJSONHandler : NSObject

+ (NSString *)encodedJSONString:(id)data;
+ (NSData *)encodedJSONData:(id)data;

@end
