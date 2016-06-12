//
//  MPPersistence.m
//  Mixpanel
//
//  Created by Sam Green on 6/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "MPPersistence.h"
#import "MPLogger.h"
#import "Mixpanel.h"

@interface MPPersistence ()

@property (nonatomic, copy) NSString *token;

@end

@implementation MPPersistence

- (instancetype)initWithToken:(NSString *)token {
    self = [super init];
    if (self) {
        self.token = token;
    }
    return self;
}

#pragma mark - Archive
- (void)archiveEventQueue:(NSMutableArray *)events {
    NSString *path = [self pathForEvents];
    MixpanelDebug(@"%@ archiving events data to %@: %@", self.token, path, events);
    if (![MPPersistence archive:events toPath:path]) {
        MixpanelError(@"%@ unable to archive events data", self.token);
    }
}

- (void)archivePeopleQueue:(NSMutableArray *)people {
    NSString *path = [self pathForPeople];
    MixpanelDebug(@"%@ archiving people data to %@: %@", self.token, path, people);
    if (![MPPersistence archive:people toPath:path]) {
        MixpanelError(@"%@ unable to archive people data", self.token);
    }
}

- (void)archiveProperties:(NSMutableDictionary *)properties {
    NSString *path = [self pathForProperties];
    MixpanelDebug(@"%@ archiving properties to %@: %@", self.token, path, properties);
    if (![MPPersistence archive:properties toPath:path]) {
        MixpanelError(@"%@ unable to archive properties", self.token);
    }
}

- (void)archiveVariants:(NSSet *)variants {
    NSString *path = [self pathForVariants];
    MixpanelDebug(@"%@ archiving variants to %@: %@", self.token, path, variants);
    if (![MPPersistence archive:variants toPath:path]) {
        MixpanelError(@"%@ unable to archive variants data", self.token);
    }
}

- (void)archiveEventBindings:(NSSet *)eventBindings {
    NSString *path = [self pathForEventBindings];
    MixpanelDebug(@"%@ archiving event bindings to %@: %@", self.token, path, eventBindings);
    if (![MPPersistence archive:eventBindings toPath:path]) {
        MixpanelError(@"%@ unable to archive variants data", self.token);
    }
}

+ (BOOL)archive:(id)object toPath:(NSString *)path {
    if (![NSKeyedArchiver archiveRootObject:object toFile:path]) {
        // TODO: Handle failure
        return NO;
    }
    return YES;
}

#pragma mark - Unarchive
- (NSMutableArray *)unarchiveEventQueue {
    return [MPPersistence unarchiveOrDefaultFromPath:[self pathForEvents]
                                             asClass:[NSMutableArray class]];
}

- (NSMutableArray *)unarchivePeopleQueue {
    return [MPPersistence unarchiveOrDefaultFromPath:[self pathForPeople]
                                             asClass:[NSMutableArray class]];
}
- (NSDictionary *)unarchiveProperties {
    return [MPPersistence unarchiveFromPath:[self pathForProperties]
                                    asClass:[NSDictionary class]];
}

- (NSSet *)unarchiveVariants {
    return [MPPersistence unarchiveFromPath:[self pathForVariants]
                                    asClass:[NSSet class]];
}

- (NSSet *)unarchiveEventBindings {
    return [MPPersistence unarchiveFromPath:[self pathForEventBindings]
                                    asClass:[NSSet class]];
}

+ (nonnull id)unarchiveOrDefaultFromPath:(NSString *)path asClass:(Class)class {
    return [self unarchiveFromPath:path asClass:class] ?: [class new];
}

+ (id)unarchiveFromPath:(NSString *)path asClass:(Class)class {
    @try {
        id unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        // this check is inside the try-catch as the unarchivedData may be a non-NSObject,
        // not responding to `isKindOfClass:` or `respondsToSelector:`
        if ([unarchivedData isKindOfClass:class]) {
            return unarchivedData;
        }
    }
    @catch (NSException *exception) {
        // Remove the (possibly) corrupt data from the disk
        NSError *error = NULL;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if (!removed || error) {
            MixpanelError(@"Failure load file at %@. File was removed. Details: %@", path, error.localizedDescription);
        }
    }
    return nil;
}

#pragma mark - Paths
- (NSString *)pathForEvents {
    return [MPPersistence pathFor:@"events" withToken:self.token];
}

- (NSString *)pathForPeople {
    return [MPPersistence pathFor:@"people" withToken:self.token];
}

- (NSString *)pathForProperties {
    return [MPPersistence pathFor:@"properties" withToken:self.token];
}

- (NSString *)pathForVariants {
    return [MPPersistence pathFor:@"variants" withToken:self.token];
}

- (NSString *)pathForEventBindings {
    return [MPPersistence pathFor:@"event_bindings" withToken:self.token];
}

+ (NSString *)pathFor:(NSString *)type withToken:(NSString *)token {
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *filename = [NSString stringWithFormat:@"mixpanel-%@-%@.plist", token, type];
    return [libraries.lastObject stringByAppendingPathComponent:filename];
}

@end
