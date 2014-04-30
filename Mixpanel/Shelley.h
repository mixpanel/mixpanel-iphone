//
//  Shelley.h
//  Shelley
//
//  Created by Pete Hodgson on 7/17/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define ShelleyView UIView

#else

#import <Cocoa/Cocoa.h>

#define ShelleyView NSObject

#endif

@class SYParser;

@interface Shelley : NSObject {
    SYParser *_parser;
    
}
+ (Shelley *) withSelectorString:(NSString *)selectorString;

- (id)initWithSelectorString:(NSString *)selectorString;

- (NSArray *) selectFrom:(ShelleyView *)rootView;
- (NSArray *) selectFromViews:(NSArray *)views;

@end
