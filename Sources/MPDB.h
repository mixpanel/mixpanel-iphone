//
//  MPDB.h
//  Mixpanel
//
//  Created by Jared McFarland on 9/17/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#ifndef MPDB_h
#define MPDB_h

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface MPDB : NSObject {
    NSString *_apiToken;
    sqlite3 *_connection;
}

@property (nonatomic, copy) NSString *apiToken;

- (instancetype)initWithToken:(NSString *)apiToken;

- (void) open;
- (void) close;

- (void) insertRow:(NSString *)persistenceType data:(NSData *)data flag:(bool) flag;
- (void) deleteRows:(NSString *)persistenceType ids:(NSArray *)ids;
- (void) updateRowsFlag:(NSString *)persistenceType newFlag:(bool)newFlag;
- (NSArray *) readRows:(NSString *)persistenceType numRows:(int)numRows flag:(bool)flag;

@end


#endif /* MPDB_h */
