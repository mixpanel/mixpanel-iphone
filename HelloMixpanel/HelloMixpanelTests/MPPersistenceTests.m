//
//  MPPersistenceTests.m
//  HelloMixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPPersistence.h"

@interface MPPersistence ()

@property (nonatomic, copy) NSString *token;

+ (nonnull id)unarchiveOrDefaultFromPath:(NSString *)path asClass:(Class)class;
+ (id)unarchiveFromPath:(NSString *)path asClass:(Class)class;

+ (BOOL)archive:(id)object toPath:(NSString *)path;

#pragma mark - Paths
- (NSString *)pathForEvents;
- (NSString *)pathForPeople;
- (NSString *)pathForProperties;
- (NSString *)pathForVariants;
- (NSString *)pathForEventBindings;

+ (NSString *)pathFor:(NSString *)type withToken:(NSString *)token;

@end

@interface MPPersistenceTests : XCTestCase

@property (nonatomic, strong) MPPersistence *persistence;

@end

static NSString *const kPersistenceTestToken = @"PersistenceUnitTestToken";
static NSString *const kTestString = @"Test";

@implementation MPPersistenceTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
    self.persistence = [[MPPersistence alloc] initWithToken:kPersistenceTestToken];
}

#pragma mark - Serialization

#pragma mark Archive
- (void)testSerializeEventQueue {
    NSMutableArray *events = [NSMutableArray arrayWithObjects:@1, @4, @7, nil];
    [self.persistence archiveEventQueue:events];
    
    NSMutableArray *unarchivedEvents = [self.persistence unarchiveEventQueue];
    XCTAssertEqualObjects(events, unarchivedEvents, @"Unarchived event queue did not match archived event queue.");
}

- (void)testSerializePeopleQueue {
    NSMutableArray *people = [NSMutableArray arrayWithObjects:@"John", @"Jane", @"Juliet", nil];
    [self.persistence archivePeopleQueue:people];
    
    NSMutableArray *unarchivedPeople = [self.persistence unarchivePeopleQueue];
    XCTAssertEqualObjects(people, unarchivedPeople, @"Unarchived people queue did not match archived people queue.");
}

- (void)testSerializeProperties {
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:@1, @"Test", @"Value", @"Key", nil];
    [self.persistence archiveProperties:properties];
    
    NSDictionary *unarchivedProperties = [self.persistence unarchiveProperties];
    XCTAssertEqualObjects(properties, unarchivedProperties, @"Unarchived properties did not match archived properties.");
}

- (void)testSerializeVariants {
    NSSet *variants = [NSSet setWithObjects:@1, @2, @3, nil];
    [self.persistence archiveVariants:variants];
    
    NSSet *unarchivedVariants = [self.persistence unarchiveVariants];
    XCTAssertEqualObjects(variants, unarchivedVariants, @"Unarchived variants did not match archived variants.");
}

- (void)testSerializeEventBindings {
    NSSet *bindings = [NSSet setWithObjects:@4, @5, @9, nil];
    [self.persistence archiveEventBindings:bindings];
    
    NSSet *unarchivedBindings = [self.persistence unarchiveEventBindings];
    XCTAssertEqualObjects(bindings, unarchivedBindings, @"Unarchived event bindings did not match archived event bindings.");
}

- (void)testArchiveInvalidObject {
    UIImage *image = [[UIImage alloc] init];
    BOOL success = [MPPersistence archive:image toPath:@""];
    XCTAssert(!success, @"Shouldn't happen; Successfully archived invalid object.");
}

- (void)testArchiveNilPath {
    BOOL success = [MPPersistence archive:@"Test" toPath:nil];
    XCTAssert(!success, @"Shouldn't happen; Successfully archived to nil path.");
}

- (void)testArchiveNilObject {
    BOOL success = [MPPersistence archive:nil toPath:@""];
    XCTAssert(!success, @"Shouldn't happen; Successfully archived nil object.");
}

- (void)testArchiveHelpers {
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = libraries.lastObject;
    NSString *path = [libraryPath stringByAppendingPathComponent:@"test-archive.plist"];
    
    BOOL success = [MPPersistence archive:kTestString toPath:path];
    XCTAssert(success, @"Failed to archived basic string to arbitrary path.");
    
    NSString *value = [MPPersistence unarchiveFromPath:path asClass:NSString.class];
    XCTAssert([value isKindOfClass:NSString.class], @"Unarchived data was not the correct class.");
    XCTAssertEqualObjects(kTestString, value, @"Unarchived data did not match archived value.");
}

- (void)testArchiveReturnsCorrectClasses {
    NSMutableArray *data = [NSMutableArray arrayWithObject:kTestString];
    
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = libraries.lastObject;
    NSString *path = [libraryPath stringByAppendingPathComponent:@"test-mutable-archive.plist"];
    
    [MPPersistence archive:data toPath:path];
    
    NSMutableArray *mutableValue = [MPPersistence unarchiveFromPath:path asClass:NSMutableArray.class];
    XCTAssert([mutableValue isKindOfClass:NSMutableArray.class]);
    
    NSArray *value = [MPPersistence unarchiveFromPath:path asClass:NSArray.class];
    XCTAssert([value isKindOfClass:NSArray.class]);
}

#pragma mark Unarchive
- (void)testUnarchiveExceptionHandling {
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = libraries.lastObject;
    NSString *path = [libraryPath stringByAppendingPathComponent:@"test-invalid-archive.plist"];
    
    NSError *error = NULL;
    [@"<xml><xml" writeToFile:path
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssert(error == NULL, @"Failed to write intentionally malformed archive.");
    
    id value = [MPPersistence unarchiveFromPath:path asClass:NSString.class];
    XCTAssertNil(value);
}

- (void)testUnarchiveOrDefault {
    NSArray *data = [MPPersistence unarchiveOrDefaultFromPath:@"" asClass:NSArray.class];
    
    XCTAssertNotNil(data);
    XCTAssert([data isKindOfClass:NSArray.class]);
    XCTAssert(data.count == 0);
}

#pragma mark - Path
#pragma mark Accessors
- (void)testPathForEvents {
    NSString *path = [self.persistence pathForEvents];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-events.plist");
}

- (void)testPathForPeople {
    NSString *path = [self.persistence pathForPeople];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-people.plist");
}

- (void)testPathForProperties {
    NSString *path = [self.persistence pathForProperties];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-properties.plist");
}

- (void)testPathForEventBindings {
    NSString *path = [self.persistence pathForEventBindings];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-event_bindings.plist");
}

- (void)testPathForVariants {
    NSString *path = [self.persistence pathForVariants];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-variants.plist");
}

//
// This caught a copy and paste error, and ensures we're not writing different data to
// the same file in two places.
//
- (void)testPathsAreUnique {
    NSArray *paths = @[ [self.persistence pathForEvents], [self.persistence pathForPeople],
                        [self.persistence pathForProperties], [self.persistence pathForEventBindings],
                        [self.persistence pathForVariants] ];
    NSSet *pathSet = [NSSet setWithArray:paths];
    XCTAssert(paths.count == pathSet.count, @"Paths are not unique.");
}

//
// Path is uniquely named based on token and type of path
//
- (void)testPathBuilder {
    NSString *path = [MPPersistence pathFor:@"TestObject" withToken:kPersistenceTestToken];
    NSString *filename = [path lastPathComponent];
    XCTAssertEqualObjects(filename, @"mixpanel-PersistenceUnitTestToken-TestObject.plist");
    
    NSString *parentDirectory = path.pathComponents[path.pathComponents.count - 2];
    XCTAssertEqualObjects(parentDirectory, @"Library");
}

@end
