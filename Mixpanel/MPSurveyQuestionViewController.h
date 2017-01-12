#import <UIKit/UIKit.h>

#import "MPSurveyQuestion.h"

@protocol MPSurveyQuestionViewControllerDelegate;

MIXPANEL_SURVEYS_DEPRECATED

@interface MPSurveyQuestionViewController : UIViewController

@property (nonatomic, weak) id<MPSurveyQuestionViewControllerDelegate> delegate;
@property (nonatomic, strong) MPSurveyQuestion *question;
@property (nonatomic, strong) UIColor *highlightColor;

@end

@protocol MPSurveyQuestionViewControllerDelegate <NSObject>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void)questionController:(MPSurveyQuestionViewController *)controller didReceiveAnswerProperties:(NSDictionary *)properties;
#pragma clang diagnostic pop

@end
