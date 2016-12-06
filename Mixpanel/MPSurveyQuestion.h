#import <Foundation/Foundation.h>

#import "Mixpanel.h"

MIXPANEL_SURVEYS_DEPRECATED

@interface MPSurveyQuestion : NSObject

@property (nonatomic, readonly) NSUInteger ID;
@property (nonatomic, readonly, strong) NSString *type;
@property (nonatomic, readonly, strong) NSString *prompt;

+ (MPSurveyQuestion *)questionWithJSONObject:(NSObject *)object;

@end

@interface MPSurveyMultipleChoiceQuestion : MPSurveyQuestion

@property (nonatomic, readonly, strong) NSArray *choices;

@end

@interface MPSurveyTextQuestion : MPSurveyQuestion

@end
