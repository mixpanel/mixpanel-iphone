#import <Foundation/Foundation.h>

#import "Mixpanel.h"

MIXPANEL_SURVEYS_DEPRECATED

@interface MPSurvey : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly, strong) NSString *name;
@property (nonatomic, readonly) NSUInteger collectionID;
@property (nonatomic, readonly, strong) NSArray *questions;

+ (MPSurvey *)surveyWithJSONObject:(NSDictionary *)object;

- (instancetype)init __unavailable;

@end
