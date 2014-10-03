#import "HomeViewController.h"
#import "MPTweakInline.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPLogo.png"]];

    MPTweakBind(self.view, alpha, @"Alpha", 1.0f, 0.0f, 1.0f);

    if (MPTweakValue(@"Proceed", NO)) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.frame = CGRectMake(50.0f, 100.0f, 0, 0);
        [button setTitle:@"Get some!" forState:UIControlStateNormal];
        [button sizeToFit];
        [self.view addSubview:button];
    }
}

@end
