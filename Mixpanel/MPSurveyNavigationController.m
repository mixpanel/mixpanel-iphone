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
    [self addChildViewController:firstQuestion];
    [self.containerView addSubview:firstQuestion.view];
    [firstQuestion didMoveToParentViewController:self];
    self.currentQuestionController = firstQuestion;
    [self updatePageNumber:0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.view.alpha = 0.0;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y - 100);
    self.previousButton.center = CGPointMake(self.previousButton.center.x, self.previousButton.center.y - 100);
    self.pageNumberLabel.center = CGPointMake(self.pageNumberLabel.center.x, self.pageNumberLabel.center.y - 100);
    self.containerView.center = CGPointMake(self.containerView.center.x, self.containerView.center.y + self.view.bounds.size.height);
    self.logo.center = CGPointMake(self.logo.center.x, self.logo.center.y + 100);
    self.exitButton.center = CGPointMake(self.exitButton.center.x, self.exitButton.center.y + 100);
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 1.0;
                         self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y + 100);
                         self.previousButton.center = CGPointMake(self.previousButton.center.x, self.previousButton.center.y + 100);
                         self.pageNumberLabel.center = CGPointMake(self.pageNumberLabel.center.x, self.pageNumberLabel.center.y + 100);
                     }
                     completion:^(BOOL finished){
                         [UIView animateWithDuration:0.5 animations:^{
                             self.containerView.center = CGPointMake(self.containerView.center.x, self.containerView.center.y - self.view.bounds.size.height);
                             self.logo.center = CGPointMake(self.logo.center.x, self.logo.center.y - 100);
                             self.exitButton.center = CGPointMake(self.exitButton.center.x, self.exitButton.center.y - 100);
                         }];
                     }
     ];
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
            controller.highlightColor = [[self.backgroundImage mp_averageColor] colorWithAlphaComponent:.6];
            self.questionControllers[index] = controller;
        }
    }
}

- (void)showQuestionAtIndex:(NSUInteger)index animatingForward:(BOOL)forward
{
    if (index < [self.survey.questions count]) {
        [self loadQuestion:index];
        UIViewController *fromController = self.currentQuestionController;
        UIViewController *toController = self.questionControllers[index];
        toController.view.transform = CGAffineTransformMakeRotation(0); // straighten out view
        toController.view.frame = self.containerView.bounds; // and then get view to size itself according to container bounds
        CGPoint cachedCenter = toController.view.center;
        if (forward) {
            // toController starts way offscreen right (the extra distance makes it move faster) and rotated 45 degrees clockwise
            toController.view.center = CGPointMake(self.view.bounds.size.width * 2, cachedCenter.y + 300);
            toController.view.transform = CGAffineTransformRotate(self.view.transform, M_PI_4);
        } else {
            // toController starts offscreen left (rotation and scaling are done with a keyframe animation)
            toController.view.center = CGPointMake(-toController.view.bounds.size.width / 2, toController.view.center.y);
        }
        [self addChildViewController:toController];
        [fromController willMoveToParentViewController:nil];
        NSTimeInterval duration = 0.3;
        [self transitionFromViewController:fromController
                          toViewController:toController
                                  duration:duration
                                   options:UIViewAnimationOptionCurveEaseIn
                                animations:^{
                                    if (forward) {
                                        // fromController slides in from right to left the whole time
                                        fromController.view.center = CGPointMake(-fromController.view.bounds.size.width / 2, fromController.view.center.y);
                                        // after a brief delay, fromController also "falls away" by rotating counterclockwise and scaling down a little
                                        NSArray *keyTimes = @[@0.0, @0.3, @1.0];
                                        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        anim.keyTimes = keyTimes;
                                        anim.values = @[@0.0, @0.0, @(-M_PI_4)];
                                        anim.duration = duration;
                                        [fromController.view.layer addAnimation:anim forKey:@"MPRotateZ"];
                                        anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
                                        anim.keyTimes = keyTimes;
                                        anim.values = @[@1.0, @1.0, @0.8];
                                        anim.duration = duration;
                                        [fromController.view.layer addAnimation:anim forKey:@"MPScale"];
                                        // toController flies up and to the left
                                        toController.view.center = cachedCenter;
                                        toController.view.transform = CGAffineTransformMakeRotation(0);
                                    } else {
                                        // fromController flies down and to the right
                                        fromController.view.center = CGPointMake(self.view.bounds.size.width * 2, cachedCenter.y + 300);
                                        fromController.view.transform = CGAffineTransformRotate(self.view.transform, M_PI_4);
                                        // toController slides in from left to right the whole time
                                        toController.view.center = cachedCenter;
                                        // toController also "falls forward" by rotating clockwise to vertical and scaling up to full size
                                        NSArray *keyTimes = @[@0.0, @0.7, @1.0];
                                        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                                        anim.keyTimes = keyTimes;
                                        anim.values = @[@(-M_PI_4), @0.0, @0.0];
                                        anim.duration = duration;
                                        [toController.view.layer addAnimation:anim forKey:@"MPRotateZ"];
                                        anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
                                        anim.keyTimes = keyTimes;
                                        anim.values = @[@0.8, @1.0, @1.0];
                                        anim.duration = duration;
                                        [toController.view.layer addAnimation:anim forKey:@"MPScale"];
                                    }
                                }
                                completion:^(BOOL finished){
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
        [self showQuestionAtIndex:currentIndex + 1 animatingForward:YES];
    }
}

- (IBAction)showPreviousQuestion
{
    NSUInteger currentIndex = [_questionControllers indexOfObject:_currentQuestionController];
    if (currentIndex > 0) {
        [self showQuestionAtIndex:currentIndex - 1 animatingForward:NO];
    }
}

- (IBAction)dismiss
{
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.alpha = 0.0;
                         self.nextButton.center = CGPointMake(self.nextButton.center.x, self.nextButton.center.y - 100);
                         self.previousButton.center = CGPointMake(self.previousButton.center.x, self.previousButton.center.y - 100);
                         self.pageNumberLabel.center = CGPointMake(self.pageNumberLabel.center.x, self.pageNumberLabel.center.y - 100);
                         self.containerView.center = CGPointMake(self.containerView.center.x, self.containerView.center.y + self.view.bounds.size.height);
                         self.logo.center = CGPointMake(self.logo.center.x, self.logo.center.y + 100);
                         self.exitButton.center = CGPointMake(self.exitButton.center.x, self.exitButton.center.y + 100);
                     }
                     completion:^(BOOL finished){
                         [self.delegate surveyNavigationControllerWasDismissed:self];
                     }];
    [self.mixpanel.people union:@{
     @"$surveys": @[@(self.survey.ID)],
     @"$collections": @[@(self.survey.collectionID)]
     }];
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
