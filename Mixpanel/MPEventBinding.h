//
//  MPEventBinding.h
//  HelloMixpanel
//
//  Created by Amanda Canyon on 7/22/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPObjectSelector.h"

@interface MPEventBinding : NSObject <NSCoding>

@property (nonatomic) NSUInteger ID;
@property (nonatomic) NSString *name;
@property (nonatomic) MPObjectSelector *path;
@property (nonatomic) NSString *eventName;

@property (nonatomic, assign) Class swizzleClass;

/*!
 @property

 @abstract
 Whether this specific binding is currently running on the device.

 @discussion
 This property will not be restored on unarchive, as the binding will need
 to be run again once the app is restarted.
 */
@property (nonatomic) BOOL running;


+ (id)bindngWithJSONObject:(id)object;
- (id)initWithEventName:(NSString *)eventName onPath:(NSString *)path;

/*!
 Method stubs. Implement them in subclasses
 */
+ (NSString *)typeName;
- (void)execute;
- (void)stop;

@end
