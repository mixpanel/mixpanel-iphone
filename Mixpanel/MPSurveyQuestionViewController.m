#import <QuartzCore/QuartzCore.h>

#import "MPSurveyQuestionViewController.h"

@interface MPSurveyQuestionViewController ()
@property(nonatomic,retain) IBOutlet UILabel *promptLabel;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *promptHeight;
@end

@interface MPSurveyMultipleChoiceQuestionViewController : MPSurveyQuestionViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,retain) MPSurveyMultipleChoiceQuestion *question;
@property(nonatomic,retain) IBOutlet UITableView *tableView;
@property(nonatomic,retain) IBOutlet UIView *tableContainer;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *tableContainerVerticalPadding;
@end

typedef NS_ENUM(NSInteger, MPSurveyTableViewCellPosition) {
    MPSurveyTableViewCellPositionTop,
    MPSurveyTableViewCellPositionMiddle,
    MPSurveyTableViewCellPositionBottom,
    MPSurveyTableViewCellPositionSingle
};

@interface MPSurveyTableViewCellBackground : UIView
@property(nonatomic,retain) UIColor *strokeColor;
@property(nonatomic,retain) UIColor *fillColor;
@property(nonatomic) MPSurveyTableViewCellPosition position;
@end

@interface MPSurveyTableViewCell : UITableViewCell
@property(nonatomic,getter=isChecked) BOOL checked;
@property(nonatomic,retain) IBOutlet UILabel *label;
@property(nonatomic,retain) IBOutlet UILabel *selectedLabel;
@property(nonatomic,retain) IBOutlet UIImageView *checkmark;
@property(nonatomic,retain) IBOutlet MPSurveyTableViewCellBackground *customBackgroundView;
@property(nonatomic,retain) IBOutlet MPSurveyTableViewCellBackground *customSelectedBackgroundView;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *selectedLabelLeadingSpace;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *checkmarkLeadingSpace;
@end

@interface MPSurveyTextQuestionViewController : MPSurveyQuestionViewController <UITextViewDelegate>
@property(nonatomic,retain) MPSurveyTextQuestion *question;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *promptTop;
@property(nonatomic,retain) IBOutlet UITextView *textView;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *textViewHeight;
@property(nonatomic,retain) IBOutlet UIView *keyboardAccessory;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *keyboardAccessoryWidth;
@property(nonatomic,retain) IBOutlet UILabel *charactersLeftLabel;
@end

@implementation MPSurveyQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _promptLabel.text = self.question.prompt;
}

- (void)resizePromptText
{
    // shrink font size to fit frame. can't use adjustsFontSizeToFitWidth and minimumScaleFactor,
    // since they only work on single line labels. minimum font size is 9.
    UIFont *font = _promptLabel.font;
    for (CGFloat size = 20; size >= 9; size--) {
        font = [font fontWithSize:size];
        CGSize constraintSize = CGSizeMake(_promptLabel.bounds.size.width, MAXFLOAT);
        CGSize sizeToFit = [_promptLabel.text sizeWithFont:font constrainedToSize:constraintSize lineBreakMode:_promptLabel.lineBreakMode];
        if (sizeToFit.height <= _promptLabel.bounds.size.height) {
            break;
        }
    }
    _promptLabel.font = font;
}

- (void)viewWillLayoutSubviews
{
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        _promptHeight.constant = 72.0;
    } else {
        _promptHeight.constant = 48.0;
    }
}

- (void)viewDidLayoutSubviews
{
    // TODO: is this the correct callback?
    [self resizePromptText];
}

- (void)dealloc
{
    self.question = nil;
    self.highlightColor = nil;
    [super dealloc];
}

@end

@implementation MPSurveyTableViewCellBackground

- (void)setPosition:(MPSurveyTableViewCellPosition)position
{
    BOOL changed = _position != position;
    _position = position;
    if (changed) {
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect
{
    UIRectCorner corners;
    if (_position == MPSurveyTableViewCellPositionTop) {
        corners = UIRectCornerTopLeft | UIRectCornerTopRight;
    } else if (_position == MPSurveyTableViewCellPositionMiddle) {
        corners = 0;
    } else if (_position == MPSurveyTableViewCellPositionBottom) {
        corners = UIRectCornerBottomLeft | UIRectCornerBottomRight;
    } else {
        // MPSurveyTableViewCellBackgroundPositionSingle
        corners = UIRectCornerAllCorners;
    }

    // pixel fitting
    rect.origin.x += 0.5;
    rect.origin.y += 0.5;
    rect.size.width -= 1;
    if (_position == MPSurveyTableViewCellPositionBottom) {
        rect.size.height -= 1;
    }

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                               byRoundingCorners:corners
                                                     cornerRadii:CGSizeMake(5, 5)];

    [path setLineCapStyle:kCGLineCapSquare];
    [_strokeColor setStroke];
    [_fillColor setFill];
    [path stroke];
    [path fill];
}

@end

@implementation MPSurveyTableViewCell

- (void)setChecked:(BOOL)checked animatedWithCompletion:(void (^)(BOOL))completion
{
    _checked = checked;
    if (checked) {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             _label.alpha = 0.0;
                             _customBackgroundView.alpha = 0.0;
                             _checkmark.alpha = 1.0;
                             _selectedLabel.alpha = 1.0;
                             _customSelectedBackgroundView.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {
                             NSTimeInterval duration = 0.25;
                             _checkmarkLeadingSpace.constant = 20.0;
                             [UIView animateWithDuration:duration
                                                   delay:0.0
                                                 options:UIViewAnimationOptionCurveEaseOut
                                              animations:^{
                                                  [self.contentView layoutIfNeeded];
                                                  _selectedLabelLeadingSpace.constant = 46.0;
                                                  [UIView animateWithDuration:duration * 0.5
                                                                        delay:duration * 0.5
                                                                      options:0
                                                                   animations:^{
                                                                       [self.contentView layoutIfNeeded];
                                                                   }
                                                                   completion:completion];
                                              }
                                              completion:nil];
                         }];
    } else {
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             _checkmark.alpha = 0.0;
                             _selectedLabel.alpha = 0.0;
                             _customSelectedBackgroundView.alpha = 0.0;
                             _checkmarkLeadingSpace.constant = 15.0;
                             _selectedLabelLeadingSpace.constant = 30.0;
                             _label.alpha = 1.0;
                             _customBackgroundView.alpha = 1.0;
                         }
                         completion:completion];
    }
}

@end

@implementation MPSurveyMultipleChoiceQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _tableView.contentInset = UIEdgeInsetsMake(44, 0, 44, 0);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1.0 alpha:0.0].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1.0 alpha:1.0].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor, (id)outerColor];
    // add 20 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 44.0 / _tableContainer.bounds.size.height;
    fadeLayer.locations = @[@0.0, @(0.0 + offset), @(1.0 - offset), @1.0];
    fadeLayer.bounds = _tableContainer.bounds;
    fadeLayer.anchorPoint = CGPointZero;
    _tableContainer.layer.mask = fadeLayer;
}

- (NSString *)labelForValue:(id)val
{
    NSString *label;
    if ([val isKindOfClass:[NSString class]]) {
        label = val;
    } else if ([val isKindOfClass:[NSNumber class]]) {
        int i = [val intValue];
        if (CFNumberGetType((CFNumberRef)val) == kCFNumberCharType && (i == 0 || i == 1)) {
            label = i ? @"Yes" : @"No";
        } else {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
            label = [formatter stringFromNumber:val];
            [formatter release];
        }
    } else if ([val isKindOfClass:[NSNull class]]) {
        label = @"None";
    } else {
        NSLog(@"%@ unexpected value for survey choice: %@", self, val);
        label = [val description];
    }
    return label;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.question.choices count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPSurveyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MPSurveyTableViewCell"];
    NSString *text = [self labelForValue:[self.question.choices objectAtIndex:indexPath.row]];
    cell.label.text = text;
    cell.selectedLabel.text = text;
    UIColor *strokeColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    cell.customBackgroundView.strokeColor = strokeColor;
    cell.customSelectedBackgroundView.strokeColor = strokeColor;
    cell.customBackgroundView.fillColor = [UIColor clearColor];
    cell.customSelectedBackgroundView.fillColor = [self.highlightColor colorWithAlphaComponent:0.3];
    MPSurveyTableViewCellPosition position;
    if (indexPath.row == 0) {
        if ([self.question.choices count] == 1) {
            position = MPSurveyTableViewCellPositionSingle;
        } else {
            position = MPSurveyTableViewCellPositionTop;
        }
    } else if (indexPath.row == (NSInteger)([self.question.choices count] - 1)) {
        position = MPSurveyTableViewCellPositionBottom;
    } else {
        position = MPSurveyTableViewCellPositionMiddle;
    }
    cell.customBackgroundView.position = position;
    cell.customSelectedBackgroundView.position = position;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPSurveyTableViewCell *cell = (MPSurveyTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    if (!cell.isChecked) {
        [cell setChecked:YES animatedWithCompletion:^(BOOL finished){
            id value = [self.question.choices objectAtIndex:indexPath.row];
            [self.delegate questionController:self didReceiveAnswerProperties:@{@"$value": value}];
        }];
    }
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPSurveyTableViewCell *cell = (MPSurveyTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    if (cell.isChecked) {
        [cell setChecked:NO animatedWithCompletion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) ? 0 : 0.1; // for some reason, 0 doesn't work in ios7
}

@end

@implementation MPSurveyTextQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _textView.backgroundColor = [self.highlightColor colorWithAlphaComponent:0.3];
    _textView.delegate = self;
    _textView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
    _textView.layer.borderWidth = 1;
    _textView.layer.cornerRadius = 5;
    _textView.inputAccessoryView = _keyboardAccessory;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self registerForKeyboardNotifications];
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        [_textView becomeFirstResponder];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_textView resignFirstResponder];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _keyboardAccessoryWidth.constant = self.view.bounds.size.width;
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        _textViewHeight.constant = 72;
    } else {
        _textViewHeight.constant = 48;
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    BOOL shouldChange;
    if ([text isEqualToString:@"\n"]) {
        // submit answer
        shouldChange = NO;
        [self.delegate questionController:self didReceiveAnswerProperties:@{@"$value": textView.text}];
    } else {
        NSInteger newLength = [textView.text length] + ([text length] - range.length);
        shouldChange = newLength <= 255;
        if (shouldChange) {
            [UIView animateWithDuration:0.3 animations:^{
                _charactersLeftLabel.text = [NSString stringWithFormat:@"%@ character%@ left", @(255 - newLength), (255 - newLength == 1) ? @"": @"s"];
                _charactersLeftLabel.alpha = (newLength > 155) ? 1 : 0;
            }];
        }
    }
    return shouldChange;
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification*)note
{
    CGFloat promptTop, promptAlpha;
    if (UIDeviceOrientationIsPortrait(([UIApplication sharedApplication].statusBarOrientation))) {
        promptTop = 0;
        promptAlpha = 1;
    } else {
        promptTop = -(self.promptLabel.bounds.size.height + 8);
        promptAlpha = 0;
    }
    _promptTop.constant = promptTop;
    NSDictionary* info = [note userInfo];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [info[UIKeyboardAnimationDurationUserInfoKey] unsignedIntegerValue];
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | curve
                     animations:^{
                         self.promptLabel.alpha = promptAlpha;
                         [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    NSLog(@"kbwillhide");
    _promptTop.constant = 0;
    NSDictionary* info = [note userInfo];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [info[UIKeyboardAnimationDurationUserInfoKey] unsignedIntegerValue];
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | curve
                     animations:^{
                         self.promptLabel.alpha = 1;
                         [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

- (IBAction)hideKeyboard
{
    [_textView resignFirstResponder];
}

@end
