#import <UIKit/UIKit.h>

#import "Mixpanel.h"
#import "MPSurvey.h"

@interface MPSurveyNavigationController : UIViewController

@property(nonatomic,retain) Mixpanel *mixpanel;
@property(nonatomic,retain) MPSurvey *survey;
@property(nonatomic,retain) UIImage *backgroundImage;

@end
