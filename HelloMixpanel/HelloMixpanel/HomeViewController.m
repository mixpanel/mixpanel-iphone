#import "HomeViewController.h"
#import "FBTweakInline.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPLogo.png"]];

    FBTweakBind(self.view, alpha, @"Main Window", @"View", @"Alpha", 1.0f, 0.0f, 1.0f);
}

@end
