#import <UIKit/UIKit.h>

#import "Mixpanel.h"
#import "MPSurvey.h"

@protocol MPSurveyNavigationControllerDelegate;

MIXPANEL_SURVEYS_DEPRECATED

@interface MPSurveyNavigationController : UIViewController

@property (nonatomic, strong) MPSurvey *survey;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, weak) id<MPSurveyNavigationControllerDelegate> delegate;

@end

@protocol MPSurveyNavigationControllerDelegate <NSObject>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void)surveyController:(MPSurveyNavigationController *)controller wasDismissedWithAnswers:(NSArray *)answers;
#pragma clang diagnostic pop

@end
