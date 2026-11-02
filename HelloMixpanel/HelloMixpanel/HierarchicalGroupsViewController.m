//
//  HierarchicalGroupsViewController.m
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "HierarchicalGroupsViewController.h"

// Hierarchical groups is an init-time option and instances are shared per token, so this page
// uses its own project rather than the one AppDelegate initializes.
static NSString *const MIXPANEL_HG_PROJECT_TOKEN = @"0d15128ec05aa2ba0fb3d45185f63a11";

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
    self.actionTitles = [NSMutableArray array];
    [self addIdentityActions];
    [self addOptOutActions];
    [self addEventActions];
    [self addUserActions];
    [self addGroupActionsWithLabel:@"Company" groupKey:@"$company_id" group:^MixpanelGroup * _Nullable {
        return [self.mixpanel getCompany];
    }];
    [self addGroupActionsWithLabel:@"Team" groupKey:@"team_id" group:^MixpanelGroup *{
        return [self.mixpanel getGroup:@"team_id" groupID:[self teamId]];
    }];
    [self addAction:@"Flush" message:@"Flush queued data" block:^{
        NSLog(@"Flushing");
        [self.mixpanel flush];
    }];
    [self addAction:@"Reset" message:@"Reset identity" block:^{
        NSLog(@"Resetting");
        [self.mixpanel reset];
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
    self.actions[title] = ^{
        [self.view endEditing:YES];
        NSLog(@"[%@] ===== %@ =====", LOGTAG, title);
        block();
        // Flush after every call so its requests show up on their own
        [self.mixpanel flush];
        [self presentLogMessage:message title:@"Hierarchical Groups"];
    };
}

- (void)addIdentityActions
{
    [self addAction:@"Identify" message:@"Identify: user + company" block:^{
        NSLog(@"Identifying %@ at %@", [self userId], [self companyId]);
        [self.mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[self userId]
                                                                           companyId:[self companyId]]];
    }];
    [self addAction:@"Invalid: Identify Without Company" message:@"Identify: user only" block:^{
        NSLog(@"Identifying %@ without a company", [self userId]);
        [self.mixpanel identifyWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[self userId] companyId:nil]];
    }];
    [self addAction:@"Invalid: Identify With Distinct ID" message:@"identify:" block:^{
        NSLog(@"Identifying %@ with identify:", [self userId]);
        [self.mixpanel identify:[self userId]];
    }];
    [self addAction:@"Invalid: Alias" message:@"createAlias:forDistinctID:" block:^{
        NSLog(@"Aliasing new_alias");
        NSString *distinctId = self.mixpanel.identity.userId ?: self.mixpanel.identity.deviceId;
        [self.mixpanel createAlias:@"new_alias" forDistinctID:distinctId ?: @""];
    }];
    [self addAction:@"Show Identity" message:@"Identity (see console)" block:^{
        NSLog(@"[%@] identity=%@ optedOut=%@ superProperties=%@", LOGTAG, self.mixpanel.identity,
              [self.mixpanel hasOptedOutTracking] ? @"YES" : @"NO", [self.mixpanel currentSuperProperties]);
    }];
}

- (void)addOptOutActions
{
    [self addAction:@"Opt Out" message:@"optOutTracking" block:^{
        NSLog(@"Opting out");
        [self.mixpanel optOutTracking];
    }];
    [self addAction:@"Opt In" message:@"optInTracking" block:^{
        NSLog(@"Opting in anonymously");
        [self.mixpanel optInTracking];
    }];
    [self addAction:@"Opt In With Identity" message:@"optInTrackingWithIdentity:properties:" block:^{
        NSLog(@"Opting in as %@ at %@", [self userId], [self companyId]);
        [self.mixpanel optInTrackingWithIdentity:[[MixpanelIdentity alloc] initWithUserId:[self userId]
                                                                                companyId:[self companyId]]
                                      properties:nil];
    }];
    [self addAction:@"Invalid: Opt In With Distinct ID" message:@"optInTrackingForDistinctID:" block:^{
        NSLog(@"Opting in as %@ with optInTrackingForDistinctID:", [self userId]);
        [self.mixpanel optInTrackingForDistinctID:[self userId]];
    }];
}

- (void)addEventActions
{
    [self addAction:@"Track Event" message:@"Event: \"HG Event!\"" block:^{
        NSLog(@"Tracking HG event");
        [self.mixpanel track:@"HG Event!" properties:@{@"source": @"hierarchical_groups_page"}];
    }];
    [self addAction:@"Set Team Group" message:@"setGroup: team_id" block:^{
        NSLog(@"Setting team_id to %@", [self teamId]);
        [self.mixpanel setGroup:@"team_id" groupID:[self teamId]];
    }];
    [self addAction:@"Invalid: Set Team Groups (List)" message:@"setGroup: team_id list" block:^{
        NSLog(@"Setting team_id to a list of %@", [self teamId]);
        [self.mixpanel setGroup:@"team_id" groupIDs:@[[self teamId]]];
    }];
    [self addAction:@"Invalid: Add Team Group" message:@"addGroup: team_id" block:^{
        NSLog(@"Adding team_id %@", [self teamId]);
        [self.mixpanel addGroup:@"team_id" groupID:[self teamId]];
    }];
    [self addAction:@"Remove Team Group" message:@"removeGroup: team_id" block:^{
        NSLog(@"Removing team_id %@", [self teamId]);
        [self.mixpanel removeGroup:@"team_id" groupID:[self teamId]];
    }];
    [self addAction:@"Track With Team Group" message:@"Event: \"HG Team Event!\"" block:^{
        NSLog(@"Tracking HG event with team_id %@", [self teamId]);
        [self.mixpanel trackWithGroups:@"HG Team Event!" properties:@{} groups:@{@"team_id": [self teamId]}];
    }];
}

- (void)addUserActions
{
    // User profile ($user_id group profile)
    [self addAction:@"User: Set Property" message:@"People: set \"plan\"" block:^{
        NSLog(@"Setting a user property");
        [self.mixpanel.people set:@"plan" to:@"enterprise"];
    }];
    [self addAction:@"User: Set Properties (Map)" message:@"People: set properties" block:^{
        NSLog(@"Setting multiple user properties");
        [self.mixpanel.people set:@{@"role": @"admin", @"seats": @5}];
    }];
    [self addAction:@"User: Set Property Once" message:@"People: setOnce \"first_seen\"" block:^{
        NSLog(@"Setting a user property once");
        [self.mixpanel.people setOnce:@{@"first_seen": @"2026-10-27"}];
    }];
    [self addAction:@"User: Union Property" message:@"People: union \"devices\"" block:^{
        NSLog(@"Union user property");
        [self.mixpanel.people union:@{@"devices": @[@"ios", @"android"]}];
    }];
    [self addAction:@"User: Remove Property" message:@"People: remove from \"devices\"" block:^{
        NSLog(@"Removing from user property");
        [self.mixpanel.people remove:@{@"devices": @"android"}];
    }];
    [self addAction:@"User: Unset Property" message:@"People: unset \"plan\"" block:^{
        NSLog(@"Unsetting a user property");
        [self.mixpanel.people unset:@[@"plan"]];
    }];
    [self addAction:@"Invalid: User Clear Charges" message:@"People: clearCharges" block:^{
        NSLog(@"Clearing charges");
        [self.mixpanel.people clearCharges];
    }];
    [self addAction:@"User: Delete User" message:@"People: deleteUser" block:^{
        NSLog(@"Deleting user");
        [self.mixpanel.people deleteUser];
    }];

    // User profile operations /groups has no equivalent for, dropped with an error log
    [self addAction:@"Invalid: User Increment" message:@"People: increment \"logins\"" block:^{
        NSLog(@"Incrementing a user property");
        [self.mixpanel.people increment:@"logins" by:@1];
    }];
    [self addAction:@"Invalid: User Increment (Map)" message:@"People: increment properties" block:^{
        NSLog(@"Incrementing multiple user properties");
        [self.mixpanel.people increment:@{@"logins": @1, @"sessions": @2}];
    }];
    [self addAction:@"Invalid: User Append" message:@"People: append \"history\"" block:^{
        NSLog(@"Appending to a user property");
        [self.mixpanel.people append:@{@"history": @"opened_hg_page"}];
    }];
    [self addAction:@"Invalid: User Track Charge" message:@"People: trackCharge 9.99" block:^{
        NSLog(@"Tracking a charge");
        [self.mixpanel.people trackCharge:@9.99];
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
