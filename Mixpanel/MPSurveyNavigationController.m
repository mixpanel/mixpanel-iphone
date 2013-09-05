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
@property(nonatomic,retain) IBOutlet UIButton *exitButton;
@property(nonatomic,retain) NSMutableArray *questionControllers;
@property(nonatomic,retain) UIViewController *currentQuestionController;

@end

@implementation MPSurveyNavigationController

- (void)dealloc
{
    self.mixpanel = nil;
    self.survey = nil;
    self.backgroundImage = nil;
    self.questionControllers = nil;
    [super dealloc];
}

- (void)viewDidLoad
{
    self.view.image = [self.backgroundImage mp_applyDarkEffect];
    self.questionControllers = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.survey.questions.count; i++) {
        [self.questionControllers addObject:[NSNull null]];
    }
    [self loadQuestion:0];
    [self loadQuestion:1];
    MPSurveyQuestionViewController *firstQuestion = self.questionControllers[0];
    //firstQuestion.view.frame = self.containerView.bounds;
    [self addChildViewController:firstQuestion];
    [self.containerView addSubview:firstQuestion.view];
    [firstQuestion didMoveToParentViewController:self];
    self.currentQuestionController = firstQuestion;
    [self updatePageNumber:0];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)updatePageNumber:(NSUInteger)index
{
    self.pageNumberLabel.text = [NSString stringWithFormat:@"%d of %d", index + 1, self.survey.questions.count];
}

- (void)loadQuestion:(NSUInteger)index
{
    if (index < self.survey.questions.count) {
        MPSurveyQuestionViewController *controller = self.questionControllers[index];
        // replace the placeholder if necessary
        if ((NSNull *)controller == [NSNull null]) {
            MPSurveyQuestion *question = self.survey.questions[index];
            NSString *storyboardIdentifier;
            if ([question isKindOfClass:[MPSurveyMultipleChoiceQuestion class]]) {
                storyboardIdentifier = @"MPSurveyMultipleChoiceQuestionViewController";
            } else if ([question isKindOfClass:[MPSurveyTextQuestion class]]) {
                storyboardIdentifier = @"MPSurveyTextQuestionViewController";
            } else {
                NSLog(@"no view controller for question: %@", question);
                return;
            }
            controller = [self.storyboard instantiateViewControllerWithIdentifier:storyboardIdentifier];
            controller.delegate = self;
            controller.question = question;
            controller.highlightColor = [[self.backgroundImage mp_averageColor] colorWithAlphaComponent:0.5];
            self.questionControllers[index] = controller;
        }
    }
}

- (void)showQuestion:(NSUInteger)index direction:(UIViewAnimationOptions)direction animated:(BOOL)animated
{
    if (index < [self.survey.questions count]) {
        [self loadQuestion:index];
        UIViewController *fromController = self.currentQuestionController;
        UIViewController *toController = self.questionControllers[index];
        toController.view.frame = self.containerView.bounds;
        [self addChildViewController:toController];
        [fromController willMoveToParentViewController:nil];
        NSTimeInterval duration = animated ? 0.2 : 0;
        [self transitionFromViewController:fromController
                          toViewController:toController
                                  duration:duration
                                   options:direction | UIViewAnimationOptionCurveEaseIn
                                animations:nil
                                completion:^(BOOL finished) {
                                    [toController didMoveToParentViewController:self];
                                    [fromController removeFromParentViewController];
                                    self.currentQuestionController = toController;
                                }];
        [self updatePageNumber:index];
        self.previousButton.enabled = index != 0;
        self.nextButton.enabled = index < ([self.survey.questions count] - 1);
        [self loadQuestion:index - 1];
        [self loadQuestion:index + 1];
    } else {
        NSLog(@"attempt to navigate to invalid question index");
    }
}

- (IBAction)showNextQuestion
{
    NSUInteger currentIndex = [_questionControllers indexOfObject:_currentQuestionController];
    if (currentIndex < (self.survey.questions.count - 1)) {
        [self showQuestion:currentIndex + 1
                 direction:UIViewAnimationOptionTransitionFlipFromLeft
                  animated:YES];
    }
}

- (IBAction)showPreviousQuestion
{
    NSUInteger currentIndex = [_questionControllers indexOfObject:_currentQuestionController];
    if (currentIndex > 0) {
        [self showQuestion:currentIndex - 1
                 direction:UIViewAnimationOptionTransitionFlipFromRight
                  animated:YES];
    }
}

- (IBAction)dismiss
{
    [self.mixpanel.people union:@{
     @"$surveys": @[@(self.survey.ID)],
     @"$collections": @[@(self.survey.collectionID)]}];
    [self.delegate surveyNavigationControllerWasDismissed:self];
}

- (void)questionViewController:(MPSurveyQuestionViewController *)controller
    didReceiveAnswerProperties:(NSDictionary *)properties
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionaryWithDictionary:properties];
    [answer addEntriesFromDictionary:@{
     @"$survey_id": @(self.survey.ID),
     @"$collection_id": @(self.survey.collectionID),
     @"$question_id": @(controller.question.ID),
     @"$time": [NSDate date]
     }];
    [self.mixpanel.people append:@{@"$answers": answer}];
    NSUInteger currentIndex = [_questionControllers indexOfObject:_currentQuestionController];
    if (currentIndex < ([self.survey.questions count] - 1)) {
        [self showNextQuestion];
    } else {
        [self dismiss];
    }
}

@end
