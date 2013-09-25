#import <QuartzCore/QuartzCore.h>

#import "MPSurvey.h"
#import "MPSurveyNavigationController.h"
#import "MPSurveyQuestion.h"
#import "MPSurveyQuestionViewController.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "UIView+MPSnapshotImage.h"

@interface MPSurveyNavigationController () <MPSurveyQuestionViewControllerDelegate>

@property(nonatomic,retain) IBOutlet UIImageView *view;
@property(nonatomic,retain) IBOutlet UIView *containerView;
@property(nonatomic,retain) IBOutlet UILabel *pageNumberLabel;
@property(nonatomic,retain) IBOutlet UIButton *nextButton;
@property(nonatomic,retain) IBOutlet UIButton *previousButton;
@property(nonatomic,retain) IBOutlet UIImageView *logo;
@property(nonatomic,retain) IBOutlet UIButton *exitButton;
@property(nonatomic,retain) IBOutlet UIView *header;
@property(nonatomic,retain) IBOutlet UIView *footer;
@property(nonatomic,retain) NSMutableArray *questionControllers;
@property(nonatomic) UIViewController *currentQuestionController;
@property(nonatomic) BOOL answeredOneQuestion;

@end

@implementation MPSurveyNavigationController

- (void)dealloc
{
    self.survey = nil;
    self.backgroundImage = nil;
    self.questionControllers = nil;
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.image = [_backgroundImage mp_applyDarkEffect];
    self.questionControllers = [NSMutableArray array];
    for (NSUInteger i = 0; i < _survey.questions.count; i++) {
        [_questionControllers addObject:[NSNull null]];
    }
    [self loadQuestion:0];
    [self loadQuestion:1];
    MPSurveyQuestionViewController *firstQuestionController = _questionControllers[0];
    [self addChildViewController:firstQuestionController];
    [_containerView addSubview:firstQuestionController.view];
    [self constrainQuestionView:firstQuestionController.view];
    [firstQuestionController didMoveToParentViewController:self];
    _currentQuestionController = firstQuestionController;
    [firstQuestionController.view setNeedsUpdateConstraints];
    [self updatePageNumber:0];
    [self updateButtons:0];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _header.center = CGPointMake(_header.center.x, _header.center.y - _header.bounds.size.height);
    _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y + self.view.bounds.size.height);
    _footer.center = CGPointMake(_footer.center.x, _footer.center.y + _footer.bounds.size.height);
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 1.0;
                         [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)updatePageNumber:(NSUInteger)index
{
    _pageNumberLabel.text = [NSString stringWithFormat:@"%d of %d", index + 1, _survey.questions.count];
}

- (void)updateButtons:(NSUInteger)index
{
    _previousButton.enabled = index > 0;
    _nextButton.enabled = index < ([_survey.questions count] - 1);
}

- (void)loadQuestion:(NSUInteger)index
{
    if (index < _survey.questions.count) {
        MPSurveyQuestionViewController *controller = _questionControllers[index];
        // replace the placeholder if necessary
        if ((NSNull *)controller == [NSNull null]) {
            MPSurveyQuestion *question = _survey.questions[index];
            NSString *storyboardIdentifier = [NSString stringWithFormat:@"%@ViewController", NSStringFromClass([question class])];
            controller = [self.storyboard instantiateViewControllerWithIdentifier:storyboardIdentifier];
            if (!controller) {
                NSLog(@"no view controller for storyboard identifier: %@", storyboardIdentifier);
                return;
            }
            controller.delegate = self;
            controller.question = question;
            controller.highlightColor = [[_backgroundImage mp_averageColor] colorWithAlphaComponent:.6];
            controller.view.translatesAutoresizingMaskIntoConstraints = NO;
            _questionControllers[index] = controller;
        }
    }
}

- (void)constrainQuestionView:(UIView *)view
{
    NSDictionary *views = NSDictionaryOfVariableBindings(view);
    [_containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
    [_containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views]];
}

- (void)showQuestionAtIndex:(NSUInteger)index animatingForward:(BOOL)forward
{
    if (index < [_survey.questions count]) {
        [self loadQuestion:index];
        UIViewController *fromController = _currentQuestionController;
        UIViewController *toController = _questionControllers[index];
        [fromController willMoveToParentViewController:nil];
        [self addChildViewController:toController];
        NSLog(@"_containerView constraints before: %@", _containerView.constraints);
        toController.view.alpha = 0.0;
        toController.view.transform = CGAffineTransformMakeRotation(M_PI_2);
        // todo: disable next and previous buttons while animating
        [self transitionFromViewController:fromController
                          toViewController:toController
                                  duration:1.0
                                   options:UIViewAnimationOptionCurveEaseIn
                                animations:^{
//                                    [_containerView removeConstraints:priorConstraints];
//                                    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
//                                    anim.duration = 1.0;
//                                    anim.byValue = @(M_PI_2);
//                                    [fromController.view.layer addAnimation:anim forKey:@"blah"];
//
//
////                                    CGPoint center = toController.view.center;
////                                    center.x += 200;
////                                    toController.view.center = center;
                                    fromController.view.transform = CGAffineTransformMakeRotation(-M_PI_2);
                                    fromController.view.alpha = 0.0;

                                    [self constrainQuestionView:toController.view];
                                    toController.view.transform = CGAffineTransformIdentity;
                                    toController.view.alpha = 1.0;
                                    [toController.view layoutIfNeeded];
                               }
                                completion:^(BOOL finished){
                                    fromController.view.transform = CGAffineTransformIdentity; // reset view
                                    [fromController removeFromParentViewController];
                                    [toController didMoveToParentViewController:self];
                                    NSLog(@"_containerView constraints after: %@", _containerView.constraints);
                                    _currentQuestionController = toController;
                                }];
        [self updatePageNumber:index];
        [self updateButtons:index];
        [self loadQuestion:index - 1];
        [self loadQuestion:index + 1];
    } else {
        NSLog(@"attempt to navigate to invalid question index");
    }
}

- (NSUInteger)currentIndex
{
    return [_questionControllers indexOfObject:_currentQuestionController];
}

- (IBAction)showNextQuestion
{
    NSUInteger currentIndex = [self currentIndex];
    if (currentIndex < (_survey.questions.count - 1)) {
        [self showQuestionAtIndex:currentIndex + 1 animatingForward:YES];
    }
}

- (IBAction)showPreviousQuestion
{
    NSUInteger currentIndex = [self currentIndex];
    if (currentIndex > 0) {
        [self showQuestionAtIndex:currentIndex - 1 animatingForward:NO];
    }
}

- (IBAction)dismiss
{
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 0.0;
                         _header.center = CGPointMake(_header.center.x, _header.center.y - 100);
                         _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y + self.view.bounds.size.height);
                         _footer.center = CGPointMake(_footer.center.x, _footer.center.y + 100);
                     }
                     completion:^(BOOL finished){
                         [_delegate surveyControllerWasDismissed:self];
                     }];
}

- (void)questionController:(MPSurveyQuestionViewController *)controller didReceiveAnswerProperties:(NSDictionary *)properties
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionaryWithDictionary:properties];
    answer[@"$collection_id"] = @(_survey.collectionID);
    answer[@"$question_id"] = @(controller.question.ID);
    answer[@"$question_type"] = controller.question.type;
    answer[@"$survey_id"] = @(_survey.ID);
    answer[@"$time"] = [NSDate date];
    [_delegate surveyController:self didReceiveAnswer:answer];
    if ([self currentIndex] < ([_survey.questions count] - 1)) {
        [self showNextQuestion];
    } else {
        [self dismiss];
    }
}

@end
