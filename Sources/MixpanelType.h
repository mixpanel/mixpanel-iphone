//
//  MixpanelType.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MixpanelType <NSObject>

- (BOOL)equalToMixpanelType:(id<MixpanelType>)rhs;

@end

@interface NSString (MixpanelTypeCategory) <MixpanelType>

@end

@interface NSNumber (MixpanelTypeCategory) <MixpanelType>

@end

@interface NSArray (MixpanelTypeCategory) <MixpanelType>

@end

@interface NSDictionary (MixpanelTypeCategory) <MixpanelType>

@end

@interface NSDate (MixpanelTypeCategory) <MixpanelType>

@end

@interface NSURL (MixpanelTypeCategory) <MixpanelType>

@end
