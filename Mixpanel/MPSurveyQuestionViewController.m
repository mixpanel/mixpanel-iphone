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
@property(nonatomic,retain) CAGradientLayer *fadeLayer;
@end

@interface MPSurveyMultipleChoiceQuestionCell : UITableViewCell
@property(nonatomic,retain) UIColor *highlightColor;
@end

@interface MPSurveyTextQuestionViewController : MPSurveyQuestionViewController <UITextViewDelegate>
@property(nonatomic,retain) IBOutlet UIScrollView *view;
@property(nonatomic,retain) MPSurveyTextQuestion *question;
@property(nonatomic,retain) IBOutlet UITextView *textView;
@end

@implementation MPSurveyQuestionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _promptLabel.text = self.question.prompt;
    [self resizePromptText];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
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

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    if (!_fadeLayer) {
//        _fadeLayer = [CAGradientLayer layer];
//        CGColorRef outerColor = [UIColor colorWithWhite:1.0 alpha:0.0].CGColor;
//        CGColorRef innerColor = [UIColor colorWithWhite:1.0 alpha:1.0].CGColor;
//        _fadeLayer.colors = @[(id)outerColor, (id)innerColor, (id)innerColor, (id)outerColor];
//        // add 20 pixels of fade in and out at top and bottom of table view container
//        CGFloat offset = 20.0 / _tableContainer.bounds.size.height;
//        _fadeLayer.locations = @[@0.0, @(0.0 + offset), @(1.0 - offset), @1.0];
//        _fadeLayer.bounds = self.tableContainer.bounds;
//        _fadeLayer.anchorPoint = CGPointZero;
//        _tableContainer.layer.mask = _fadeLayer;
//    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
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
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // submit on return
    if ([text hasSuffix:@"\n"]) {
        [self.delegate questionViewController:self didReceiveAnswerProperties:@{@"$value": textView.text}];
        return NO;
    }
    // 255 character max
    return [textView.text length] + ([text length] - range.length) <= 255;
}

@end
