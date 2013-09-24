#import <QuartzCore/QuartzCore.h>

#import "MPSurveyQuestionViewController.h"

@interface MPSurveyQuestionViewController ()
@property(nonatomic,retain) IBOutlet UILabel *promptLabel;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *promptHeight;
@end

@interface MPSurveyMultipleChoiceQuestionViewController : MPSurveyQuestionViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,retain) MPSurveyMultipleChoiceQuestion *question;
@property(nonatomic,retain) IBOutlet UIImageView *checkmarkImageView;
@property(nonatomic,retain) IBOutlet UITableView *tableView;
@property(nonatomic,retain) IBOutlet UIView *tableContainer;
@end

@interface MPSurveyMultipleChoiceQuestionCell : UITableViewCell
@property(nonatomic,retain) UIColor *highlightColor;
@end

@interface MPSurveyTextQuestionViewController : MPSurveyQuestionViewController <UITextViewDelegate>
@property(nonatomic,retain) MPSurveyTextQuestion *question;
@property(nonatomic,retain) IBOutlet UIScrollView *scrollView;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *scrollViewBottomSpace;
@property(nonatomic,retain) IBOutlet UIView *contentView;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *contentWidth;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *contentHeight;
@property(nonatomic,retain) IBOutlet UITextView *textView;
@property(nonatomic,retain) IBOutlet UIView *keyboardAccessory;
@property(nonatomic,retain) IBOutlet NSLayoutConstraint *keyboardAccessoryWidth;
@property(nonatomic,retain) IBOutlet UILabel *charactersLeftLabel;
@property(nonatomic,retain) IBOutlet UIButton *doneButton;
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

@implementation MPSurveyMultipleChoiceQuestionViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    CGColorRef outerColor = [UIColor colorWithWhite:1.0 alpha:0.0].CGColor;
    CGColorRef innerColor = [UIColor colorWithWhite:1.0 alpha:1.0].CGColor;
    fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor, (id)outerColor];
    // add 20 pixels of fade in and out at top and bottom of table view container
    CGFloat offset = 20.0 / _tableContainer.bounds.size.height;
    fadeLayer.locations = @[@0.0, @(0.0 + offset), @(1.0 - offset), @1.0];
    fadeLayer.bounds = self.tableContainer.bounds;
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.question.choices count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPSurveyMultipleChoiceQuestionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MPSurveyMultipleChoiceQuestionCell"];
    cell.highlightColor = self.highlightColor;
    cell.textLabel.text = [self labelForValue:[self.question.choices objectAtIndex:indexPath.row]];
    return cell;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.highlighted = YES;
    cell.accessoryView = self.checkmarkImageView;
    id value = [self.question.choices objectAtIndex:indexPath.row];
    [self.delegate questionViewController:self didReceiveAnswerProperties:@{@"$value": value}];
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.highlighted = NO;
    cell.accessoryView = nil;
}

@end

@implementation MPSurveyMultipleChoiceQuestionCell

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (highlighted) {
        self.backgroundColor = self.highlightColor;
        self.textLabel.backgroundColor = [UIColor clearColor];
    } else {
        self.backgroundColor = [UIColor clearColor];
    }
}

@end

@implementation MPSurveyTextQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _textView.backgroundColor = self.highlightColor;
    _textView.delegate = self;
    _textView.layer.borderColor = [UIColor whiteColor].CGColor;
    _textView.layer.borderWidth = 1;
    _textView.layer.cornerRadius = 5;
    _textView.inputAccessoryView = _keyboardAccessory;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self registerForKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_textView resignFirstResponder];
    _scrollViewBottomSpace.constant = 0;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _keyboardAccessoryWidth.constant = self.view.bounds.size.width;
    _contentWidth.constant = self.view.bounds.size.width;
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        _contentHeight.constant = 208;
    } else {
        _contentHeight.constant = 184;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _scrollView.contentSize = CGSizeMake(_contentWidth.constant, _contentHeight.constant);
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSInteger newLength = [textView.text length] + ([text length] - range.length);
    BOOL shouldChange = newLength <= 255;
    if (shouldChange) {
        [UIView animateWithDuration:0.3 animations:^{
            _charactersLeftLabel.text = [NSString stringWithFormat:@"%@ characters left", @(255 - newLength)];
            _charactersLeftLabel.alpha = (newLength > 155) ? 1.0 : 0.0;
            _doneButton.enabled = newLength > 0;
            _doneButton.alpha = (newLength > 0) ? 1.0 : 0.3;

        }];
    }
    return shouldChange;
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardDidShow:(NSNotification*)note
{
    NSDictionary* info = [note userInfo];
    CGSize kbSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [info[UIKeyboardAnimationDurationUserInfoKey] unsignedIntegerValue];
    CGFloat height;
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        height = kbSize.height;
    } else {
        height = kbSize.width;
    }
    height -= 44.0;
    _scrollViewBottomSpace.constant = height;
    [_scrollView setNeedsUpdateConstraints];
    CGRect textViewTop = _textView.frame;
    textViewTop.size.height = 48.0;
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | curve
                     animations:^{
                         [self.view layoutIfNeeded];
                         [_scrollView scrollRectToVisible:textViewTop animated:YES];
                     }
                     completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    _scrollViewBottomSpace.constant = 0;
}

- (IBAction)cancelEditingText
{
    [_textView resignFirstResponder];
}

- (IBAction)submitText
{
    [self.delegate questionViewController:self didReceiveAnswerProperties:@{@"$value": _textView.text}];
}

@end
