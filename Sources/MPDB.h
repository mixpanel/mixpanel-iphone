//
//  MPDB.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPDB : NSObject

@property (nonatomic, readonly, copy) NSString *apiToken;

- (instancetype)initWithToken:(NSString *)apiToken;

- (void)open;
- (void)close;

- (void)insertRow:(NSString *)persistenceType data:(NSData *)data flag:(BOOL) flag;
- (void)deleteRows:(NSString *)persistenceType ids:(NSArray *)ids isDeleteAll:(BOOL)isDeleteAll;
- (void)updateRowsFlag:(NSString *)persistenceType newFlag:(BOOL)newFlag;
- (NSArray *)readRows:(NSString *)persistenceType numRows:(NSInteger)numRows flag:(BOOL)flag;
// Runs block in one transaction, so its writes are all kept or none are. Returns NO, without running
// block, when the transaction can't be started.
- (BOOL)performInTransaction:(void (^)(void))block;

@end
