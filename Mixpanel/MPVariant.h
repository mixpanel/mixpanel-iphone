//
//  MPVariant.h
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 28/4/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPVariant : NSObject <NSCoding>

@property (nonatomic) NSUInteger ID;
@property (nonatomic) NSUInteger experimentID;

/*!
 @property

 @abstract
 Whether this specific variant is currently running on the device.

 @discussion
 This property will not be restored on unarchive, as the variant will need
 to be run again once the app is restarted.
 */
@property (nonatomic, readonly)BOOL running;

/*!
 @property

 @abstract
 Whether the variant should not run anymore.

 @discussion
 Variants are set to finished when we no longer see them in a decide response.
 If set, the test will not be run anymore the next time the app starts.
*/
@property (nonatomic, readonly) BOOL finished;

+ (MPVariant *)variantWithJSONObject:(NSDictionary *)object;

- (void) addActionsFromJSONObject:(NSArray *)actions andExecute:(BOOL)exec;
- (void) addActionFromJSONObject:(NSDictionary *)object andExecute:(BOOL)exec;
- (void) addTweaksFromJSONObject:(NSArray *)tweaks andExecute:(BOOL)exec;
- (void) addTweakFromJSONObject:(NSDictionary *)object andExecute:(BOOL)exec;
- (void)removeActionWithName:(NSString *)name;
- (void)execute;
- (void)stop;
- (void)finish;

@end

@interface MPVariantAction : NSObject <NSCoding>

@end

@interface MPVariantTweak : NSObject <NSCoding>

@end
