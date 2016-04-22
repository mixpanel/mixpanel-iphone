//
//  EventBindingTests.m
//  EventBindingTests
//
//  Created by Amanda Canyon on 8/18/14.
//  Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import "Mixpanel.h"
#import "MPEventBinding.h"
#import "MPObjectSelector.h"
#import "MPUIControlBinding.h"
#import "MPUITableViewBinding.h"

#define TEST_TOKEN @"xxxxxxxxxxxxxxxxxxxxxxx"

# pragma mark - The stub object for recording method calls
@interface MixpanelStub : NSObject

@property (nonatomic) NSMutableArray *calls;
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;
- (void)resetCalls;

@end

@implementation MixpanelStub

- (instancetype)init
{
    if (self = [super init]) {
        _calls = [NSMutableArray array];
    }
    return self;
}

- (void)track:(NSString *)event
{
    [self.calls addObject:@{@"event": event}];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self.calls addObject:@{@"event": event, @"properties": properties}];
}

- (void)resetCalls
{
    self.calls = [NSMutableArray array];
}

@end

@interface TableController : UITableViewController<UITableViewDelegate,UITableViewDataSource>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

@end
@implementation TableController

- (instancetype)init
{
    if (self = [super init]) {
        self.tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
        self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        [self.tableView reloadData];
    }
    return self;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"selected something");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[UITableViewCell alloc] init];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

@end

@interface EventBindingTests : XCTestCase

@property (nonatomic) MixpanelStub *mixpanelStub;
@property (nonatomic) id mockMixpanelClass;

@end

@implementation EventBindingTests

- (void)setUp
{
    [super setUp];

    [Mixpanel sharedInstanceWithToken:TEST_TOKEN];
    _mixpanelStub = [[MixpanelStub alloc] init];
    _mockMixpanelClass = OCMPartialMock([Mixpanel sharedInstance]);
    OCMStub([_mockMixpanelClass track:[OCMArg any]]).andCall(_mixpanelStub, @selector(track:));
    OCMStub([_mockMixpanelClass track:[OCMArg any] properties:[OCMArg any]]).andCall(_mixpanelStub, @selector(track:properties:));
}

- (void)tearDown
{
    [self.mockMixpanelClass stopMocking];
    self.mixpanelStub = nil;
    self.mockMixpanelClass = nil;

    [super tearDown];
}

- (void)testMixpanelMock
{
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0,
                   @"Mixpanel track should not have been called.");

    [[Mixpanel sharedInstance] track:@"SOMETHING"];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 1,
                   @"Mixpanel track should have been called once.");
    XCTAssertEqual([self.mixpanelStub calls][0][@"event"],
                   @"SOMETHING", @"Mixpanel track should have been called with the event name");
}

- (void)testUIControlBindings
{
    /*
         nc__vc__v1___v2___c1
                  \    \...c3
                   \__c2
    */

    NSString *c1_path = @"/UIViewController/UIView/UIView/UIControl";
    NSString *c2_path = @"/UIViewController/UIView/UIControl";
    NSDictionary *eventParams = @{
                                  @"event_type": @"ui_control",
                                  @"event_name": @"ui control",
                                  @"path": c1_path,
                                  @"control_event": @64 // touchUpInside
                                  };


    // Create elements in window
    UIViewController *vc = [[UIViewController alloc] init];
    UIView *v1 = [[UIView alloc] init];
    UIView *v2 = [[UIView alloc] init];
    UIControl *c1 = [[UIControl alloc] init];
    UIControl *c2 = [[UIControl alloc] init];
    [v2 addSubview:c1];
    [v1 addSubview:v2];
    [v1 addSubview:c2];
    vc.view = v1;
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    ((UINavigationController *) rootViewController).viewControllers = @[vc];

    // Check paths of elements c1 and c2
    MPObjectSelector *selector = [MPObjectSelector objectSelectorWithString:c1_path];
    XCTAssertEqual([selector selectFromRoot:rootViewController][0], c1, @"c1 should be selected by path");
    selector = [MPObjectSelector objectSelectorWithString:c2_path];
    XCTAssertEqual([selector selectFromRoot:rootViewController][0], c2, @"c2 should be selected by path");

    // Create binding and check state
    MPUIControlBinding *binding = [MPEventBinding bindngWithJSONObject:eventParams];
    [binding execute];
    XCTAssertEqual([binding class], [MPUIControlBinding class], @"Binding type should be a UIControl binding");
    XCTAssertEqual([binding running], YES, @"Binding should be running");
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0,
                   @"Mixpanel track should not have been called.");

    // Fire event
    [c1 sendActionsForControlEvents:UIControlEventTouchDown];
    [c1 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 1, @"A track call should have been fired");

    // test that event doesnt fire for other UIControl
    [self.mixpanelStub resetCalls];
    [c2 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"Should not have fired event for c2");

    // test `didMoveToWindow`
    [self.mixpanelStub resetCalls];
    UIControl *c3 = [[UIControl alloc] init];
    [v2 addSubview:c3];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"Mixpanel track should not have been called.");
    [c3 sendActionsForControlEvents:UIControlEventTouchDown];
    [c3 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 1, @"A track call should have been fired");


    /*
         nc__vc__v1___v2___c1
                  \...c3
                   \__c2
     */
    // test moving element to different path
    [self.mixpanelStub resetCalls];
    [v1 addSubview:c3];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"Mixpanel track should not have been called.");
    [c3 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"A track call should not have been fired");

    // test `stop` with c1
    [self.mixpanelStub resetCalls];
    [binding stop];
    XCTAssertEqual([binding running], NO, @"Binding should NOT be running");
    [c1 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"Target action should have been unbound");
    [c1 removeFromSuperview]; [v2 addSubview:c1]; // -- remove and replace
    selector = [MPObjectSelector objectSelectorWithString:c1_path];
    XCTAssertEqual([selector selectFromRoot:rootViewController][0], c1, @"c1 should have been replaced");
    [c1 sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"didMoveToWindow should have been unSwizzled");


    // Test archive
    NSData* archive = [NSKeyedArchiver archivedDataWithRootObject:binding];
    MPUIControlBinding* unarchivedBinding = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    XCTAssertEqual(binding.ID, unarchivedBinding.ID, @"Binding should have correct serialized properties after archive");
    XCTAssertEqual(binding.class, unarchivedBinding.class, @"Binding should have correct serialized properties after archive");
    XCTAssertTrue([binding.name isEqualToString:unarchivedBinding.name], @"Binding should have correct serialized properties after archive");
    XCTAssertTrue([binding.path.string isEqualToString:unarchivedBinding.path.string], @"Binding should have correct serialized properties after archive");
    XCTAssertEqual(binding.controlEvent, unarchivedBinding.controlEvent, @"Binding should have correct serialized properties after archive");
    XCTAssertEqual(binding.verifyEvent, unarchivedBinding.verifyEvent, @"Binding should have correct serialized properties after archive");

}

- (void)testUITableViewBindings
{
    /*
         nc__vc__tv
     */

    NSString *tv_path = @"/UIViewController/UITableView";
    NSDictionary *eventParams = @{
                                  @"event_type": @"ui_table_view",
                                  @"event_name": @"ui table view",
                                  @"table_delegate": @"TableController",
                                  @"path": tv_path
                                  };


    // Create elements in window
    TableController *vc = [[TableController alloc] init];
    UITableView *tv = vc.tableView;  // table view has two cells
    vc.view = tv;
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    ((UINavigationController *) rootViewController).viewControllers = @[vc];

    // Check paths of elements va and vb
    MPObjectSelector *selector = [MPObjectSelector objectSelectorWithString:tv_path];
    XCTAssertEqual([selector selectFromRoot:rootViewController][0], tv, @"va should be selected by path");

    // Create binding and check state
    MPEventBinding *binding = [MPEventBinding bindngWithJSONObject:eventParams];
    [binding execute];
    XCTAssertEqual([binding class], [MPUITableViewBinding class], @"Binding type should be a UIControl binding");
    XCTAssertEqual([binding running], YES, @"Binding should be running");
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"No track calls should be fired");

    // test row selection
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    [vc tableView:tv didSelectRowAtIndexPath:indexPath];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 1, @"One track call should be fired");

    // test stop binding
    [self.mixpanelStub resetCalls];
    [binding stop];
    XCTAssertEqual([binding running], NO, @"Binding should NOT be running");
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"No track calls should be fired");

    // test row selection
    indexPath = [NSIndexPath indexPathForRow:2 inSection:0];
    [vc tableView:tv didSelectRowAtIndexPath:indexPath];
    XCTAssertEqual((int)[[self.mixpanelStub calls] count], 0, @"No track calls should be fired");

    // Test archive
    NSData* archive = [NSKeyedArchiver archivedDataWithRootObject:binding];
    MPUITableViewBinding* unarchivedBinding = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    XCTAssertEqual(binding.ID, unarchivedBinding.ID, @"Binding should have correct serialized properties after archive");
    XCTAssertEqual(binding.class, unarchivedBinding.class, @"Binding should have correct serialized properties after archive");
    XCTAssertTrue([binding.name isEqualToString:unarchivedBinding.name], @"Binding should have correct serialized properties after archive");
    XCTAssertTrue([binding.path.string isEqualToString:unarchivedBinding.path.string], @"Binding should have correct serialized properties after archive");

}

- (void)testFingerprinting
{
    NSString *format;
    /*
     Selector matching is already tested pretty well in ABTestingTests.
     This adds some tests for the fingerprint versioning.
     */
    UIView *v1 = [[UIView alloc] init];
    UIButton *b1 = [[UIButton alloc] initWithFrame:CGRectMake(2, 3, 4, 5)];
    [b1 setTitle: @"button" forState:UIControlStateNormal];
    [v1 addSubview:b1];
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"checkerboard" withExtension:@"jpg"]]];
    [b1 setImage:image forState:UIControlStateNormal];

    // Assert that we have versioning available and we are at least at v1
    XCTAssert([b1 respondsToSelector:NSSelectorFromString(@"mp_fingerprintVersion")]);
    XCTAssert([b1 performSelector:NSSelectorFromString(@"mp_fingerprintVersion")] >= 1);


    // Test a versioned predicate where the first clause passes and the second would fail
    format = @"(mp_fingerprintVersion >= 1 AND true == true) OR 1 = 2";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    XCTAssert([[MPObjectSelector objectSelectorWithString:([NSString stringWithFormat:@"/UIButton[%@]", format])] isLeafSelected:b1 fromRoot:v1], @"Selector should have selected object matching predicate");

    // Test where the version check fails (running an older version of the lib than the one called for in the predicate)
    format = @"(mp_fingerprintVersion >= 9999999 AND mp_crashOlderApps = \"crash\") OR 1 = 1";
    XCTAssert([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    XCTAssert([[MPObjectSelector objectSelectorWithString:([NSString stringWithFormat:@"/UIButton[%@]", format])] isLeafSelected:b1 fromRoot:v1], @"Selector should have selected object matching predicate");

    // Test where the version check passes but the version-sensitive predicate fails
    format = @"(mp_fingerprintVersion >= 1 AND mp_varA = \"not a real return value\") OR 1 = 2";
    XCTAssertFalse([[NSPredicate predicateWithFormat:format] evaluateWithObject:b1]);
    XCTAssertFalse([[MPObjectSelector objectSelectorWithString:([NSString stringWithFormat:@"/UIButton[%@]", format])] isLeafSelected:b1 fromRoot:v1], @"Selector should have selected object matching predicate");
}

- (void)testInvalidEventBindings
{
    // This event binding references a class (NoSuchController) that
    // doesn't exist. Running the binding should have no effect.
    NSString *badData = @"YnBsaXN0MDDUAQIDBAUGIiNYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0\
b3ASAAGGoKgHCBUWFxgZGlUkbnVsbNYJCgsMDQ4PEBESExRSSURUcGF0aFYkY2xh\
c3NUbmFtZVlldmVudE5hbWVSJDCAAoAEgAeAA4AFgAYQAF8QJDg3QUMyRDU2LTc4\
OEUtNEYyNS05MEE0LTc4MDVCQUFENkYwOF8QHS9VSVZpZXdDb250cm9sbGVyL1VJ\
VGFibGVWaWV3XXVpIHRhYmxlIHZpZXdfEBBOb1N1Y2hDb250cm9sbGVy0hscHR5a\
JGNsYXNzbmFtZVgkY2xhc3Nlc18QFE1QVUlUYWJsZVZpZXdCaW5kaW5nox8gIV8Q\
FE1QVUlUYWJsZVZpZXdCaW5kaW5nXk1QRXZlbnRCaW5kaW5nWE5TT2JqZWN0XxAP\
TlNLZXllZEFyY2hpdmVy0SQlVHJvb3SAAQAIABEAGgAjAC0AMgA3AEAARgBTAFYA\
WwBiAGcAcQB0AHYAeAB6AHwAfgCAAIIAqQDJANcA6gDvAPoBAwEaAR4BNQFEAU0B\
XwFiAWcAAAAAAAACAQAAAAAAAAAmAAAAAAAAAAAAAAAAAAABaQ==";
    MPUIControlBinding *badBinding = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSData alloc] initWithBase64EncodedString:badData options:0]];
    [badBinding execute]; // This should have no effect, and should not raise.
}


@end
