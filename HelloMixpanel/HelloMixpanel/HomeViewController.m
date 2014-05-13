#import "HomeViewController.h"
#import "MPTweakInline.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPLogo.png"]];

    MPTweakBind(self.view, alpha, @"Main Window", @"View", @"Alpha", 1.0f);
}

@end
