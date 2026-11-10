//
//  HierarchicalGroupsViewController.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "HierarchicalGroupsViewController.h"

// Hierarchical groups is an init-time option and instances are shared per token, so this page
// uses its own project rather than the one AppDelegate initializes.
static NSString *const MIXPANEL_HG_PROJECT_TOKEN = @"YOUR_HG_PROJECT_TOKEN";

// Filter the console on "HGDemo" to see each button's header, followed by the SDK's own logs
// for what the call did.
static NSString *const LOGTAG = @"HGDemo";

typedef void (^HGActionBlock)(void);

@interface HierarchicalGroupsViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *userIdField;
@property (nonatomic, strong) UITextField *companyIdField;
@property (nonatomic, strong) UITextField *teamIdField;
@property (nonatomic, strong) NSMutableDictionary *actions;
@property (nonatomic, strong) NSMutableArray *actionTitles;

@end

@implementation HierarchicalGroupsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Hierarchical Groups";

    // No automatic events, so each flush sends only what the button's call queued
    self.mixpanel = [Mixpanel sharedInstanceWithToken:MIXPANEL_HG_PROJECT_TOKEN
                                 trackAutomaticEvents:NO
                                   hierarchicalGroups:YES];
    self.mixpanel.enableLogging = YES;

    self.userIdField = [self textFieldWithPlaceholder:@"User ID" text:@"tyler_objc"];
    self.companyIdField = [self textFieldWithPlaceholder:@"Company ID" text:@"violet_tiger"];
    self.teamIdField = [self textFieldWithPlaceholder:@"Team ID" text:@"objc_team"];
    self.tableView.tableHeaderView = [self headerViewWithFields:@[self.userIdField, self.companyIdField, self.teamIdField]];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.actions = [NSMutableDictionary dictionary];
    __weak HierarchicalGroupsViewController *weakSelf = self;
    self.actionTitles = [NSMutableArray array];
    [self addIdentityActions];
    [self addOptOutActions];
    [self addEventActions];
    [self addUserActions];
    [self addGroupActionsWithLabel:@"Company" groupKey:@"$company_id" group:^MixpanelGroup * _Nullable {
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return nil;
        }
        return [strongSelf.mixpanel getCompany];
    }];
    [self addGroupActionsWithLabel:@"Team" groupKey:@"team_id" group:^MixpanelGroup *{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return nil;
        }
        return [strongSelf.mixpanel getGroup:@"team_id" groupID:[strongSelf teamId]];
    }];
    [self addAction:@"Flush" message:@"Flush queued data" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Flushing");
        [strongSelf.mixpanel flush];
    }];
    [self addAction:@"Reset" message:@"Reset identity" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Resetting");
        [strongSelf.mixpanel reset];
    }];

    self.trackActions = self.actions;
    self.trackActionsArray = self.actionTitles;
    [self.tableView reloadData];
}

#pragma mark - Fields

- (NSString *)userId
{
    return self.userIdField.text;
}

- (NSString *)companyId
{
    return self.companyIdField.text;
}

- (NSString *)teamId
{
    return self.teamIdField.text;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text
{
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.text = text;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;

    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@" %@: ", placeholder];
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = [UIColor grayColor];
    [label sizeToFit];
    field.leftView = label;
    field.leftViewMode = UITextFieldViewModeAlways;
    return field;
}

- (UIView *)headerViewWithFields:(NSArray<UITextField *> *)fields
{
    CGFloat padding = 16;
    CGFloat fieldHeight = 36;
    CGFloat spacing = 8;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    CGFloat height = padding * 2 + fields.count * fieldHeight + (fields.count - 1) * spacing;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    CGFloat y = padding;
    for (UITextField *field in fields) {
        field.frame = CGRectMake(padding, y, width - padding * 2, fieldHeight);
        field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [header addSubview:field];
        y += fieldHeight + spacing;
    }
    return header;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Actions

- (void)addAction:(NSString *)title message:(NSString *)message block:(HGActionBlock)block
{
    [self.actionTitles addObject:title];
    // Weak, as self keeps this block in actions
    __weak HierarchicalGroupsViewController *weakSelf = self;
    self.actions[title] = ^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.view endEditing:YES];
        NSLog(@"[%@] ===== %@ =====", LOGTAG, title);
        block();
        // Flush after every call so its requests show up on their own
        [strongSelf.mixpanel flush];
        [strongSelf presentLogMessage:message title:@"Hierarchical Groups"];
    };
}

- (void)addIdentityActions
{
    __weak HierarchicalGroupsViewController *weakSelf = self;
    [self addAction:@"Identify" message:@"Identify: user + company" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Identifying %@ at %@", [strongSelf userId], [strongSelf companyId]);
        [strongSelf.mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[strongSelf userId]
                                                                                 companyId:[strongSelf companyId]]];
    }];
    [self addAction:@"Invalid: Identify Without Company" message:@"Identify: user only" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Identifying %@ without a company", [strongSelf userId]);
        [strongSelf.mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[strongSelf userId] companyId:nil]];
    }];
    [self addAction:@"Invalid: Identify With Distinct ID" message:@"identify:" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Identifying %@ with identify:", [strongSelf userId]);
        [strongSelf.mixpanel identify:[strongSelf userId]];
    }];
    [self addAction:@"Invalid: Alias" message:@"createAlias:forDistinctID:" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Aliasing new_alias");
        NSString *distinctId = strongSelf.mixpanel.identity.userId ?: strongSelf.mixpanel.identity.deviceId;
        [strongSelf.mixpanel createAlias:@"new_alias" forDistinctID:distinctId ?: @""];
    }];
    [self addAction:@"Show Identity" message:@"Identity (see console)" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"[%@] identity=%@ optedOut=%@ superProperties=%@", LOGTAG, strongSelf.mixpanel.identity,
              [strongSelf.mixpanel hasOptedOutTracking] ? @"YES" : @"NO", [strongSelf.mixpanel currentSuperProperties]);
    }];
}

- (void)addOptOutActions
{
    __weak HierarchicalGroupsViewController *weakSelf = self;
    [self addAction:@"Opt Out" message:@"optOutTracking" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Opting out");
        [strongSelf.mixpanel optOutTracking];
    }];
    [self addAction:@"Opt In" message:@"optInTracking" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Opting in anonymously");
        [strongSelf.mixpanel optInTracking];
    }];
    [self addAction:@"Opt In With Identity" message:@"optInTrackingWithIdentity:properties:" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Opting in as %@ at %@", [strongSelf userId], [strongSelf companyId]);
        [strongSelf.mixpanel optInTrackingWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[strongSelf userId]
                                                                                      companyId:[strongSelf companyId]]
                                            properties:nil];
    }];
    [self addAction:@"Invalid: Opt In With Distinct ID" message:@"optInTrackingForDistinctID:" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Opting in as %@ with optInTrackingForDistinctID:", [strongSelf userId]);
        [strongSelf.mixpanel optInTrackingForDistinctID:[strongSelf userId]];
    }];
}

- (void)addEventActions
{
    __weak HierarchicalGroupsViewController *weakSelf = self;
    [self addAction:@"Track Event" message:@"Event: \"HG Event!\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Tracking HG event");
        [strongSelf.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];
    }];
    [self addAction:@"Set Team Group" message:@"setGroup: team_id" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Setting team_id to %@", [strongSelf teamId]);
        [strongSelf.mixpanel setGroup:@"team_id" groupID:[strongSelf teamId]];
    }];
    [self addAction:@"Invalid: Set Team Groups (List)" message:@"setGroup: team_id list" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Setting team_id to a list of %@", [strongSelf teamId]);
        [strongSelf.mixpanel setGroup:@"team_id" groupIDs:@[[strongSelf teamId]]];
    }];
    [self addAction:@"Invalid: Add Team Group" message:@"addGroup: team_id" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Adding team_id %@", [strongSelf teamId]);
        [strongSelf.mixpanel addGroup:@"team_id" groupID:[strongSelf teamId]];
    }];
    [self addAction:@"Remove Team Group" message:@"removeGroup: team_id" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Removing team_id %@", [strongSelf teamId]);
        [strongSelf.mixpanel removeGroup:@"team_id" groupID:[strongSelf teamId]];
    }];
    [self addAction:@"Track With Team Group" message:@"Event: \"HG Team Event!\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Tracking HG event with team_id %@", [strongSelf teamId]);
        [strongSelf.mixpanel trackWithGroups:@"HG Team Event!" properties:@{} groups:@{@"team_id": [strongSelf teamId]}];
    }];
}

- (void)addUserActions
{
    __weak HierarchicalGroupsViewController *weakSelf = self;
    // User profile ($user_id group profile)
    [self addAction:@"User: Set Property" message:@"People: set \"plan\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Setting a user property");
        [strongSelf.mixpanel.people set:@"plan" to:@"enterprise"];
    }];
    [self addAction:@"User: Set Properties (Map)" message:@"People: set properties" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Setting multiple user properties");
        [strongSelf.mixpanel.people set:@{@"role": @"admin", @"seats": @5}];
    }];
    [self addAction:@"User: Set Property Once" message:@"People: setOnce \"first_seen\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Setting a user property once");
        [strongSelf.mixpanel.people setOnce:@{@"first_seen": @"2026-10-27"}];
    }];
    [self addAction:@"User: Union Property" message:@"People: union \"devices\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Union user property");
        [strongSelf.mixpanel.people union:@{@"devices": @[@"ios", @"android"]}];
    }];
    [self addAction:@"User: Remove Property" message:@"People: remove from \"devices\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Removing from user property");
        [strongSelf.mixpanel.people remove:@{@"devices": @"android"}];
    }];
    [self addAction:@"User: Unset Property" message:@"People: unset \"plan\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Unsetting a user property");
        [strongSelf.mixpanel.people unset:@[@"plan"]];
    }];
    [self addAction:@"Invalid: User Clear Charges" message:@"People: clearCharges" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Clearing charges");
        [strongSelf.mixpanel.people clearCharges];
    }];
    [self addAction:@"User: Delete User" message:@"People: deleteUser" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Deleting user");
        [strongSelf.mixpanel.people deleteUser];
    }];

    // User profile operations /groups has no equivalent for, dropped with an error log
    [self addAction:@"Invalid: User Increment" message:@"People: increment \"logins\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Incrementing a user property");
        [strongSelf.mixpanel.people increment:@"logins" by:@1];
    }];
    [self addAction:@"Invalid: User Increment (Map)" message:@"People: increment properties" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Incrementing multiple user properties");
        [strongSelf.mixpanel.people increment:@{@"logins": @1, @"sessions": @2}];
    }];
    [self addAction:@"Invalid: User Append" message:@"People: append \"history\"" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Appending to a user property");
        [strongSelf.mixpanel.people append:@{@"history": @"opened_hg_page"}];
    }];
    [self addAction:@"Invalid: User Track Charge" message:@"People: trackCharge 9.99" block:^{
        HierarchicalGroupsViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSLog(@"Tracking a charge");
        [strongSelf.mixpanel.people trackCharge:@9.99];
    }];
}

// The same group profile operations, for the company and for the custom team_id group. The group
// is nil when there is no company, and messaging nil does nothing
- (void)addGroupActionsWithLabel:(NSString *)label groupKey:(NSString *)groupKey group:(MixpanelGroup * _Nullable (^)(void))group
{
    [self addAction:[NSString stringWithFormat:@"%@: Set Property", label]
            message:[NSString stringWithFormat:@"Group: set \"tier\" on %@", groupKey]
              block:^{
        NSLog(@"Setting a %@ property", label);
        [group() set:@{@"tier": @"enterprise"}];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Set Properties (Map)", label]
            message:[NSString stringWithFormat:@"Group: set properties on %@", groupKey]
              block:^{
        NSLog(@"Setting multiple %@ properties", label);
        [group() set:@{@"size": @12, @"region": @"us"}];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Set Property Once", label]
            message:[NSString stringWithFormat:@"Group: setOnce \"created\" on %@", groupKey]
              block:^{
        NSLog(@"Setting a %@ property once", label);
        [group() setOnce:@{@"created": @"2026-10-27"}];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Union Property", label]
            message:[NSString stringWithFormat:@"Group: union \"tags\" on %@", groupKey]
              block:^{
        NSLog(@"Union %@ property", label);
        [group() union:@"tags" values:@[@"ios"]];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Remove Property", label]
            message:[NSString stringWithFormat:@"Group: remove from \"tags\" on %@", groupKey]
              block:^{
        NSLog(@"Removing from %@ property", label);
        [group() remove:@"tags" value:@"ios"];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Unset Property", label]
            message:[NSString stringWithFormat:@"Group: unset \"tier\" on %@", groupKey]
              block:^{
        NSLog(@"Unsetting a %@ property", label);
        [group() unset:@"tier"];
    }];
    [self addAction:[NSString stringWithFormat:@"%@: Delete Group", label]
            message:[NSString stringWithFormat:@"Group: delete %@", groupKey]
              block:^{
        NSLog(@"Deleting %@ group", label);
        [group() deleteGroup];
    }];
}

@end
