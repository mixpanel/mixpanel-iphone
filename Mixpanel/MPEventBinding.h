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
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) MPObjectSelector *path;
@property (nonatomic, copy) NSString *eventName;

@property (nonatomic, assign) Class swizzleClass;

/*!
 Whether this specific binding is currently running on the device.

 This property will not be restored on unarchive, as the binding will need
 to be run again once the app is restarted.
 */
@property (nonatomic) BOOL running;

+ (id)bindingWithJSONObject:(id)object;

- (instancetype)init __unavailable;
- (instancetype)initWithEventName:(NSString *)eventName onPath:(NSString *)path;

/*!
 Intercepts track calls and adds a property indicating the track event
 was from a binding
 */
+ (void)track:(NSString *)event properties:(NSDictionary *)properties;
/*!
 Method stubs. Implement them in subclasses
 */
+ (NSString *)typeName;
- (void)execute;
- (void)stop;

@end
