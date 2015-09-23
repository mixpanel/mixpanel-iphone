//
//  SecretWhisperViewControllerTableViewController.m
//  HelloMixpanel
//
//  Created by Alex Hofsteede on 12/5/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "SecretTableViewCell.h"
#import "SecretWhisperViewController.h"

@interface SecretWhisperViewController ()

@property (nonatomic, strong) NSArray *tableData;

@end

@implementation SecretWhisperViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    _tableData = @[ @{@"text": @"Neil always takes coffee but never makes a fresh batch", @"location": @"Mixpanel", @"likes":@2, @"comments":@1, @"image": @"http://supersonicsunflower.com/wp-content/uploads/2014/01/w-Giant-Coffee-Cup75917.jpg"},
                    @{@"text": @"Sometimes I break the site just for fun.", @"location": @"Mixpanel Engineer", @"likes":@10, @"comments":@0},
                    @{@"text": @"I take naps in Tron.", @"location": @"Mixpanel", @"likes":@2, @"comments":@1},
                    @{@"text": @"I hear that you and your band sold your guitars and bought turntables.", @"location": @"Mixpanel", @"likes":@2, @"comments":@1},
                    @{@"text": @"I heard ...", @"location": @"Mixpanel", @"likes":@2, @"comments":@1}
                    ];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (int)[_tableData count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SecretTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SecretTableViewCell" forIndexPath:indexPath];

    NSDictionary *secret = _tableData[[indexPath indexAtPosition:1]];
    cell.contentLabel.text = secret[@"text"];
    cell.locationLabel.text = secret[@"location"];
    cell.likeslabel.text = [NSString stringWithFormat:@"%@", secret[@"likes"] ];
    cell.commentsLabel.text = [NSString stringWithFormat:@"%@", secret[@"comments"] ];

    if (secret[@"image"]) {
        cell.backgroundImage.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:secret[@"image"]]]];
    } else {
        cell.backgroundImage.image = nil;
    }

    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
