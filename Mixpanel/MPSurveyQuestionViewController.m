#import <QuartzCore/QuartzCore.h>

#import "MPSurveyQuestionViewController.h"

@interface MPSurveyQuestionViewController ()
@property(nonatomic,retain) IBOutlet UILabel *promptLabel;
@end

@interface MPSurveyMultipleChoiceQuestionViewController : MPSurveyQuestionViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,retain) MPSurveyMultipleChoiceQuestion *question;
@end

@interface MPSurveyMultipleChoiceQuestionCell : UITableViewCell
@property(nonatomic,retain) UIColor *highlightColor;
@end

@interface MPSurveyTextQuestionViewController : MPSurveyQuestionViewController <UITextViewDelegate>
@property(nonatomic,retain) MPSurveyTextQuestion *question;
@property(nonatomic,retain) IBOutlet UITextView *textView;
@end

@implementation MPSurveyQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _promptLabel.text = self.question.prompt;
    // shrink font size to fit frame. can't use adjustsFontSizeToFitWidth and minimumScaleFactor,
    // since they only work on single line labels. minimum font size is 9.
    UIFont *font = _promptLabel.font;
    for (CGFloat size = _promptLabel.font.pointSize; size >= 9; size--) {
        font = [font fontWithSize:size];
        CGSize constraintSize = CGSizeMake(_promptLabel.preferredMaxLayoutWidth, MAXFLOAT);
        CGSize sizeToFit = [_promptLabel.text sizeWithFont:font constrainedToSize:constraintSize lineBreakMode:_promptLabel.lineBreakMode];
        if (sizeToFit.height <= 76) {
            break;
        }
    }
    _promptLabel.font = font;
}

- (void)dealloc
{
    self.question = nil;
    self.highlightColor = nil;
    [super dealloc];
}

@end

@implementation MPSurveyMultipleChoiceQuestionViewController

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
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    NSDictionary *answer = [self.question.choices objectAtIndex:indexPath.row];
    [self.delegate questionViewController:self didReceiveAnswerProperties:@{@"$answer": answer}];
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.highlighted = NO;
    cell.accessoryType = UITableViewCellAccessoryNone;
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
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_textView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_textView resignFirstResponder];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text hasSuffix:@"\n"]) {
        [self.delegate questionViewController:self didReceiveAnswerProperties:@{@"$answer": _textView.text}];
        return NO;
    }
    return YES;
}

@end
