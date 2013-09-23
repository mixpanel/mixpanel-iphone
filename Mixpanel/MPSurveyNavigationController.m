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
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *keyboardHeight;
@property(nonatomic,retain) NSMutableArray *questionControllers;
@property(nonatomic) UIViewController *currentQuestionController;

@end

@implementation MPSurveyNavigationController

- (void)dealloc
{
    self.mixpanel = nil;
    self.survey = nil;
    self.backgroundImage = nil;
    self.questionControllers = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
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
    [firstQuestionController didMoveToParentViewController:self];
    _currentQuestionController = firstQuestionController;
    [self updatePageNumber:0];
    [self updateButtons:0];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.view.alpha = 1.0;
//    _header.center = CGPointMake(_header.center.x, _header.center.y - 100);
//    _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y + self.view.bounds.size.height);
//    _footer.center = CGPointMake(_footer.center.x, _footer.center.y + 100);
//    [UIView animateWithDuration:0.5
//                     animations:^{
//                         self.view.alpha = 1.0;
//                         _header.center = CGPointMake(_header.center.x, _header.center.y + 100);
//                     }
//                     completion:^(BOOL finished1){
//                         [_currentQuestionController beginAppearanceTransition:YES animated:NO];
//                         [UIView animateWithDuration:0.5
//                                          animations:^{
//                                              _containerView.center = CGPointMake(_containerView.center.x, _containerView.center.y - self.view.bounds.size.height);
//                                              _footer.center = CGPointMake(_footer.center.x, _footer.center.y - 100);
//                                          }
//                                          completion:^(BOOL finished2) {
//                                              [_currentQuestionController endAppearanceTransition];
//                                          }];
//                     }];
}

- (void)resizeViewForKeyboard:(NSNotification*)note up:(BOOL)up {
    NSDictionary *userInfo = [note userInfo];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    CGFloat height;
    if (up) {
        CGRect kbFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        BOOL isPortrait = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
        height = isPortrait ? kbFrame.size.height : kbFrame.size.width;
    } else {
        height = 0;
    }
    self.keyboardHeight.constant = height;
    [self.view setNeedsUpdateConstraints];
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardWillShow:(NSNotification*)note
{
    [self resizeViewForKeyboard:note up:YES];
}

- (void)keyboardWillHide:(NSNotification*)note
{
    [self resizeViewForKeyboard:note up:NO];
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
            _questionControllers[index] = controller;
        }
    }
}

- (void)showQuestionAtIndex:(NSUInteger)index animatingForward:(BOOL)forward
{
    if (index < [_survey.questions count]) {
        [self loadQuestion:index];
        UIViewController *fromController = _currentQuestionController;
        UIViewController *toController = _questionControllers[index];
        [self addChildViewController:toController];
        [fromController willMoveToParentViewController:nil];
        [toController.view layoutIfNeeded];

//        toController.view.transform = CGAffineTransformMakeRotation(0); // straighten out view
//        toController.view.frame = _containerView.bounds; // and then get view to size itself according to container bounds
        CGPoint cachedCenter = toController.view.center;

        if (forward) {
            // toController starts way offscreen right (the extra distance makes it move faster) and rotated 45 degrees clockwise
            toController.view.center = CGPointMake(self.view.bounds.size.width * 2, cachedCenter.y + 300);
            toController.view.transform = CGAffineTransformRotate(self.view.transform, M_PI_4);
        } else {
            // toController starts offscreen left (rotation and scaling are done with a keyframe animation)
            toController.view.center = CGPointMake(-toController.view.bounds.size.width / 2, toController.view.center.y);
        }
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
                                        NSArray *keyTimes = @[@0.0, @0.4, @1.0];
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
                                        NSArray *keyTimes = @[@0.0, @0.6, @1.0];
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
                                    _currentQuestionController = toController;
                                    toController.view.frame = _containerView.bounds;
                                    [toController.view layoutIfNeeded];
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
                         [_delegate surveyNavigationControllerWasDismissed:self];
                     }];
    [_mixpanel.people union:@{@"$surveys": @[@(_survey.ID)],
                              @"$collections": @[@(_survey.collectionID)]}];
}

- (void)questionViewController:(MPSurveyQuestionViewController *)controller
    didReceiveAnswerProperties:(NSDictionary *)properties
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionaryWithDictionary:properties];
    [answer addEntriesFromDictionary:@{@"$survey_id": @(_survey.ID),
                                       @"$collection_id": @(_survey.collectionID),
                                       @"$question_id": @(controller.question.ID),
                                       @"$question_type": controller.question.type,
                                       @"$time": [NSDate date]}];
    [_mixpanel.people append:@{@"$answers": answer}];
    if ([self currentIndex] < ([_survey.questions count] - 1)) {
        [self showNextQuestion];
    } else {
        [self dismiss];
    }
}

@end
