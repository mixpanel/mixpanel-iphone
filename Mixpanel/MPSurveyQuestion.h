#import <Foundation/Foundation.h>

#import "Mixpanel.h"

MIXPANEL_SURVEYS_DEPRECATED

@interface MPSurveyQuestion : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly, strong) NSString *type;
@property (nonatomic, readonly, strong) NSString *prompt;

+ (MPSurveyQuestion *)questionWithJSONObject:(NSObject *)object;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
@interface MPSurveyMultipleChoiceQuestion : MPSurveyQuestion
#pragma clang diagnostic pop

@property (nonatomic, readonly, strong) NSArray *choices;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
@interface MPSurveyTextQuestion : MPSurveyQuestion
#pragma clang diagnostic pop

@end
