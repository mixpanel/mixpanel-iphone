//
//  SettingsViewControllerTableViewController.m
//  SampleApp
//
//

#import "SettingsViewControllerTableViewController.h"

@interface SettingsViewControllerTableViewController () <UITextFieldDelegate>{
    __weak IBOutlet UISegmentedControl *tokenSegment;
    __weak IBOutlet UISegmentedControl *serverSegment;
    __weak IBOutlet UISegmentedControl *eventTypeSegment;
    
    __weak IBOutlet UISwitch *stringSwitch;
    __weak IBOutlet UITextField *stringTextField;
    
    __weak IBOutlet UISegmentedControl *objectTypeSegment;
    __weak IBOutlet UISwitch *keySwitch;
    __weak IBOutlet UITextField *keyTextField;
    
    __weak IBOutlet UISwitch *propertiesSwitch;
    __weak IBOutlet UILabel *timedEventsLabel;
    
    int eventsCount;
}

@property (nonatomic, strong) Alooma *alooma;

@end

@implementation SettingsViewControllerTableViewController

@synthesize alooma;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    eventsCount = 0;
    
    [stringTextField setDelegate:self];
    [keyTextField setDelegate:self];
    
    alooma = [self createAlooma];
}

- (Alooma*)createAlooma{
    NSArray *tokens = @[@"ValidToken", @"InvalidToken"];
    NSArray *serverURLs = @[@"https://mobixon-qa.alooma.io", @"http://www.BadServerAddressThatsnotgonnaworkzzzzzz.com"];
    
    return [[Alooma alloc] initWithToken:tokens[tokenSegment.selectedSegmentIndex]
                               serverURL:serverURLs[serverSegment.selectedSegmentIndex] andFlushInterval:60];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendEvent{
    NSDictionary *object = nil;
    
    // event is object or object+string && object is not nil
    NSDictionary *itemsDictionary = @{};
    if (eventTypeSegment.selectedSegmentIndex > 0 && objectTypeSegment.selectedSegmentIndex > 0){
        itemsDictionary = @{ @"key_str" : @"val1", @"key_float" : @(1.5), @"key_bool" : @(YES), @"key_int" : @(1983), @"key_date" : [NSDate date], @"key_array" : @[@"arr_val1", @"arr_val2", @"arr_val3"]};
        
        object = keySwitch.isOn ? @{keyTextField.text : itemsDictionary} : itemsDictionary;
    }
    
    switch (eventTypeSegment.selectedSegmentIndex) {
        case 0:
            // string
            [alooma track:stringSwitch.isOn ? stringTextField.text : nil];
            break;
        case 1:
            // object
            [alooma trackCustomEvent:object];
            break;
        case 2:
            // string + object
            [alooma track:stringSwitch.isOn ? stringTextField.text : nil
              customEvent:object];
            break;
        case 3:
            [alooma track:stringSwitch.isOn ? stringTextField.text : nil properties:itemsDictionary];
            break;
        default:
            break;
    }
    
    eventsCount++;
    [self.delegate statusChanged:[NSString stringWithFormat:@"Event queued! total: %d", eventsCount]];
}

- (IBAction)eventTypeSegmentValueChanged:(id)sender {
    switch (((UISegmentedControl*)sender).selectedSegmentIndex) {
        case 0:
            // string
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:YES];
            
            [objectTypeSegment setEnabled:NO];
            [keySwitch setEnabled:NO];
            [keyTextField setEnabled:NO];
            break;
        case 1:
            // object
            [stringSwitch setEnabled:NO];
            [stringTextField setEnabled:NO];

            [objectTypeSegment setEnabled:YES];
            [keySwitch setEnabled:YES];
            [keyTextField setEnabled:YES];
            break;
        case 2:
            // string + object
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:YES];

            [objectTypeSegment setEnabled:YES];
            [keySwitch setEnabled:YES];
            [keyTextField setEnabled:YES];
            break;
        case 3:
            // string + properties
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:YES];
            
            [objectTypeSegment setEnabled:NO];
            [keySwitch setEnabled:NO];
            [keyTextField setEnabled:NO];
            break;
        default:
            break;
    }
}

- (IBAction)objectTypeSegmentValueChanged:(id)sender {
    
    //        case 0:
    // nil
    //        case 1:
    // items
    
    [keySwitch setEnabled:((UISegmentedControl*)sender).selectedSegmentIndex == 1];
    [keyTextField setEnabled:((UISegmentedControl*)sender).selectedSegmentIndex == 1];
}

- (IBAction)stringSwitchValueChanged:(id)sender {
    [stringTextField setEnabled:((UISwitch*)sender).isOn];
}

- (IBAction)keySwitchValueChanged:(id)sender {
    [keyTextField setEnabled:((UISwitch*)sender).isOn];
}

- (IBAction)tokenSelectValueChanged:(id)sender {
    alooma = [self createAlooma];
}

- (IBAction)serverSelectValueChanged:(id)sender {
    alooma = [self createAlooma];
}

- (IBAction)superPropertiesSwichValueChanged:(id)sender {
    if (((UISwitch*)sender).isOn){
        [alooma registerSuperProperties:@{ @"super_key_str" : @"super properties", @"super_key_float" : @(1.5), @"super_key_bool" : @(YES), @"super_key_int" : @(100), @"super_key_date" : [NSDate date], @"super_key_array" : @[@"arr_val1", @"arr_val2", @"arr_val3"]}];
    }
    else{
        [alooma clearSuperProperties];
    }
}

- (IBAction)registerSuperPropertiesOnceButtonClicked:(id)sender {
    [alooma registerSuperPropertiesOnce:@{ @"super_key_str2" : @"super properties once", @"super_key_float" : @(111.111), @"super_key_bool" : @(NO)}];
    [self.delegate statusChanged:@"Registered super properties Once"];
}

- (IBAction)registerSuperPropertiesOnceAndDefault:(id)sender {
    [alooma registerSuperPropertiesOnce:@{ @"super_key_str" : @"super properties once + default", @"super_key_float" : @(123.123), @"super_key_bool" : @(NO)} defaultValue:@"super properties"];
    [self.delegate statusChanged:@"Registered super properties Once + Overwrite default"];
}

- (IBAction)removePropertyButtonClicked:(id)sender {
    [alooma unregisterSuperProperty:@"super_key_str"];
    [self.delegate statusChanged:@"super_key_str property unregistered"];
}

- (IBAction)resetButtonClicked:(id)sender {
    [alooma reset];
    
    [propertiesSwitch setOn:NO];
    eventsCount = 0;
    
    [self.delegate statusChanged:@"Properties were reset"];
}

- (IBAction)registerTimedEventsSwitchValueChanged:(id)sender {
    if (((UISwitch*)sender).isOn){
        [alooma timeEvent:stringTextField.text];
        [timedEventsLabel setText:[NSString stringWithFormat:@"Registered events: \"%@\"", stringTextField.text]];
    }
    else {
        [alooma clearTimedEvents];
        [timedEventsLabel setText:@"Register timed events"];
    }
}

- (void)flushEvents{
    [self.alooma flush];
    eventsCount = 0;
    
    [self.delegate statusChanged:@"Flushing now!"];
}

#pragma mark UITextFieldDelegate methods
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Potentially incomplete method implementation.
//    // Return the number of sections.
//    return 0;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#warning Incomplete method implementation.
//    // Return the number of rows in the section.
//    return 0;
//}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
