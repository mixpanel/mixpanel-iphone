#import "HomeViewController.h"

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    if (@available(iOS 12.0, *)) {
            switch (UIScreen.mainScreen.traitCollection.userInterfaceStyle) {
                case UIUserInterfaceStyleDark:
                     self.view.backgroundColor = [UIColor clearColor];
                    break;
                case UIUserInterfaceStyleLight:
                case UIUserInterfaceStyleUnspecified:
                    break;
                default:
                    break;
            }
    }
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPLogo.png"]];
}



@end
