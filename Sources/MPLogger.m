//
//  MPLogger.m
//  Mixpanel
//
//  Created by ZIHE JIA on 11/8/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import "MPLogger.h"


@implementation MPLogger

+ (MPLogger *)sharedInstance
{
    static MPLogger *sharedMPLogger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMPLogger = [[self alloc] init];
        sharedMPLogger.loggingEnabled = NO;
    });
    return sharedMPLogger;
}


@end
