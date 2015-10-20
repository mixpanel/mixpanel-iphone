//
//  ViewController.m
//  SampleApp
//
//

#import "ViewController.h"
#import "SettingsViewControllerTableViewController.h"

@interface ViewController () <SettingsDelegate>{
    __weak IBOutlet UILabel *statusLabel;
    
    SettingsViewControllerTableViewController *aloomaSettings;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"Settings"]){
        aloomaSettings = segue.destinationViewController;
        [aloomaSettings setDelegate:self];
    }
}

#pragma mark - SettingsDelegate methods
- (void)statusChanged:(NSString *)status{
    [statusLabel setText:status];
}

//- (void)didReceiveMemoryWarning {
//    [super didReceiveMemoryWarning];
//    // Dispose of any resources that can be recreated.
//}

- (IBAction)sentEventButtonClicked:(id)sender {
    [aloomaSettings sendEvent];
}

- (IBAction)sendBulkEventsButtonClicked:(id)sender {
    [(UIButton*)sender setEnabled:NO];

    for (int i = 0 ; i < 200 ; i++) {
        [aloomaSettings sendEvent];
    }
    
    [(UIButton*)sender setEnabled:YES];
}
- (IBAction)flushNowButtonClicked:(id)sender {
    [aloomaSettings flushEvents];
}


@end
