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
    
    __weak IBOutlet UIButton *registerSuperPropsButton;
    __weak IBOutlet UIButton *timedEventsButton;
    __weak IBOutlet UITextField *superPropertyOnceValue;
    __weak IBOutlet UITextField *superPropertyToRemove;
    
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
    
    alooma = [self createAlooma];
}

- (Alooma*)createAlooma{
    NSArray *tokens = @[@"ValidToken", @"InvalidToken"];
    NSArray *serverURLs = @[@"https://queen-i.alooma.io", @"http://www.BadServerAddressThatsnotgonnaworkzzzzzz.com"];
    
    return [[Alooma alloc] initWithToken:tokens[tokenSegment.selectedSegmentIndex]
                               serverURL:serverURLs[serverSegment.selectedSegmentIndex] andFlushInterval:60];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendEvent{
    NSString *event = stringSwitch.isOn ? stringTextField.text : nil;

    NSDictionary *object = objectTypeSegment.selectedSegmentIndex == 0 ? nil :
        @{ @"event" : @"customEventObject",
           @"custom_string" : @"val1",
           @"custom_float" : @(1.5),
           @"custom_bool" : @(YES),
           @"custom_int" : @(1983),
           @"custom_date" : [NSDate date],
           @"custom_array" : @[@"arr_val1", @"arr_val2", @"arr_val3"]};
    
    
    switch (eventTypeSegment.selectedSegmentIndex) {
        case 0:
            // track:
            [alooma track:event];
            break;
        case 1:
            // track: props:
            [alooma track:event properties:object];
            break;
        case 2:
            // trackCustomEvent:
            [alooma trackCustomEvent:object];
            break;
        case 3:
            // track:CustomEvent
            [alooma track:event
              customEvent:object];
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
            // track: (allow string only)
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:YES];
            
            [objectTypeSegment setEnabled:NO];
            break;
        case 1:
            // track:props: (allow string + obj)
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:stringSwitch.isOn];

            [objectTypeSegment setEnabled:YES];
            break;
        case 2:
            // trackCustomEvent: (allow only object)
            [stringSwitch setEnabled:NO];
            [stringTextField setEnabled:NO];

            [objectTypeSegment setEnabled:YES];
            break;
        case 3:
            // track:CustomEvent: (allow string + obj)
            [stringSwitch setEnabled:YES];
            [stringTextField setEnabled:stringSwitch.isOn];
            
            [objectTypeSegment setEnabled:YES];
            break;
        default:
            break;
    }
}

- (IBAction)objectTypeSegmentValueChanged:(id)sender {
}

- (IBAction)stringSwitchValueChanged:(id)sender {
    [stringTextField setEnabled:((UISwitch*)sender).isOn];
}

- (IBAction)tokenSelectValueChanged:(id)sender {
    alooma = [self createAlooma];
    [self.delegate statusChanged:@"Alooma re-initialized"];
}

- (IBAction)serverSelectValueChanged:(id)sender {
    alooma = [self createAlooma];
    [self.delegate statusChanged:@"Alooma re-initialized"];
}

- (IBAction)registerSuperPropertiesButtonPressed:(id)sender {
    [alooma registerSuperProperties:@{
                                      @"super_prop_str" : @"super properties",
                                      @"super_prop_float" : @(1.5),
                                      @"super_prop_bool" : @(YES),
                                      @"super_prop_int" : @(100),
                                      @"super_prop_date" : [NSDate date],
                                      @"super_prop_array" : @[@"sup_arr_val1", @"sup_arr_val2", @"sup_arr_val3"]}];
    [self.delegate statusChanged:@"Registered super properties"];
}

- (IBAction)clearSuperPropertiesButtonPressed:(id)sender {
    [alooma clearSuperProperties];
    [self.delegate statusChanged:@"Cleared super properties"];

}

- (IBAction)registerSuperPropertiesOnceButtonClicked:(id)sender {
    if (superPropertyOnceValue.text.length == 0) {
        [self.delegate statusChanged:@"Please enter a value to set in the super property"];
        return;
    }
    [alooma registerSuperPropertiesOnce:@{
          @"super_prop_once" : superPropertyOnceValue.text
          }];
    [self.delegate statusChanged:@"Registered a super property Once"];
}

- (IBAction)registerSuperPropertiesOnceAndDefault:(id)sender {
    [alooma registerSuperPropertiesOnce:@{
          @"super_prop_once" : superPropertyOnceValue.text,
          } defaultValue:@"default-one-time-value"];
    [self.delegate statusChanged:@"Registered super properties Once + Overwrite default"];
}

- (IBAction)removePropertyButtonClicked:(id)sender {
    if (superPropertyToRemove.text.length == 0) {
        [self.delegate statusChanged:@"Please enter a name of a super property to remove"];
        return;
    }
    [alooma unregisterSuperProperty:superPropertyToRemove.text];
    [self.delegate statusChanged:[NSString stringWithFormat:@"Removed the super prop: %@",
                                  superPropertyToRemove.text]];
}

- (IBAction)resetButtonClicked:(id)sender {
    [alooma reset];
    
    eventsCount = 0;
    
    [self.delegate statusChanged:@"Alooma was reset"];
}

- (IBAction)registerTimedEventsPressed:(id)sender {
    if (stringTextField.text != nil && stringTextField.text.length > 0){
        [alooma timeEvent:stringTextField.text];
        [self.delegate statusChanged:[NSString stringWithFormat:@"Duration measured for: \"%@\"", stringTextField.text]];
    } else {
        [self.delegate statusChanged:[NSString stringWithFormat:@"Can't measure duration for event with no name"]];
    }
}

- (IBAction)clearTimedEventsPressed:(id)sender {
    [alooma clearTimedEvents];
    [self.delegate statusChanged:@"Cleared timed events"];
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
