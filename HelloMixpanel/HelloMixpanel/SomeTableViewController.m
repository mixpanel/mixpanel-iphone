//
//  SomeTableViewController.m
//
//  Created by Amanda Canyon on 8/26/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import "SomeTableViewController.h"

@interface SomeTableViewController ()

@end

@implementation SomeTableViewController
{
    NSArray *animals;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    animals = @[@"penguins", @"elephannt", @"giraffe", @"salmon", @"jaguar", @"narwal", @"blue whale", @"gekko", @"koala", @"wombat", @"dingo", @"aardvark", @"bonobo", @"gibbon", @"tortoise", @"anaconda", @"kiwi", @"red panda", @"axolotl", @"salamander", @"army ants", @"butterfly", @"sparrow", @"mouse", @"sloth", @"howler monkey" ];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (int)[animals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"SimpleTableItem";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    cell.textLabel.text = animals[(unsigned)indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"!!!! selected");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return @"First section";
    } else {
        return @"Second section";
    }
}

@end

