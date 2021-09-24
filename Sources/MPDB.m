//
//  MPDB.m
//  Mixpanel
//
//  Created by Jared McFarland on 9/17/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#import "MPDB.h"

@implementation MPDB : NSObject

@synthesize apiToken = _apiToken;

static sqlite3 *_connection;

- (instancetype) initWithToken:(NSString *)token {
    self = [super init];
    if (self) {
        self.apiToken = token;
        [self open];
    }
    return self;
}

- (NSString *) pathToDB {
    NSString *filename = [NSString stringWithFormat:@"%@_MPDB.sqlite", self.apiToken];
#if !defined(MIXPANEL_TVOS)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#else
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
#endif
}

- (NSString *) tableNameFor:(NSString *)persistenceType {
    return [NSString stringWithFormat:@"mixpanel_%@_%@", self.apiToken, persistenceType];
}

- (void) reconnect {
    NSLog(@"No database connection found. Calling [MPDB open]");
    [self open];
}

- (void) open {
    if (!self.apiToken) {
        NSLog(@"Project token must not be empty. Database cannot be opened.");
        return;
    }
    NSString *dbPath = [self pathToDB];
    if (dbPath) {
        if (sqlite3_open_v2([dbPath UTF8String], &_connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK ) {
            [self logSqlError: [NSString stringWithFormat:@"Error opening or creating database at path: %@", dbPath]];
            [self close];
        } else {
            NSLog(@"Successfully opened connection to database at path: %@", dbPath);
            [self createTables];
        }
    }
}

- (void) close {
    sqlite3_close(_connection);
    _connection = nil;
    NSLog(@"Connection to database closed.");
}

- (void) recreate {
    [self close];
    NSString *dbPath = [self pathToDB];
    if (dbPath) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:dbPath]) {
            NSError *error = nil;
            [manager removeItemAtPath:dbPath error:&error];
            if (error) {
                NSLog(@"Unable to remove database file at path: %@ error: %@", dbPath, error);
            } else {
                NSLog(@"Deleted database file at path: %@", dbPath);
            }
        }
    }
    [self reconnect];
}

- (void) createTableFor:(NSString *)persistenceType {
    if (_connection) {
        NSString *tableName = [self tableNameFor:persistenceType];
        NSString *createTableString = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(id integer primary key autoincrement,data blob,time real, flag integer);", tableName];
        sqlite3_stmt *createTableStatement;
        if (sqlite3_prepare_v2(_connection, [createTableString UTF8String], -1, &createTableStatement, nil) == SQLITE_OK) {
            if (sqlite3_step(createTableStatement) == SQLITE_DONE) {
                NSLog(@"%@ table created", tableName);
            } else {
                [self logSqlError:[NSString stringWithFormat:@"%@ table create failed", tableName]];
            }
        } else {
            [self logSqlError:[NSString stringWithFormat:@"CREATE statement for table %@ could not be prepared", tableName]];
        }
        sqlite3_finalize(createTableStatement);
    } else {
        [self reconnect];
    }
}

- (void) createTables {
    [self createTableFor:@"events"];
    [self createTableFor:@"people"];
    [self createTableFor:@"groups"];
}

- (void) insertRow:(NSString *)persistenceType data:(NSData *)data flag:(bool) flag {
    if (_connection) {
        NSString *tableName = [self tableNameFor:persistenceType];
        NSString *insertString = [NSString stringWithFormat:@"INSERT INTO %@ (data, flag, time) VALUES(?, ?, ?);", tableName];
        sqlite3_stmt *insertStatement;
        if (sqlite3_prepare_v2(_connection, [insertString UTF8String], -1, &insertStatement, nil) == SQLITE_OK) {
            sqlite3_bind_blob(insertStatement, 1, [data bytes], (int)[data length], SQLITE_TRANSIENT);
            sqlite3_bind_int(insertStatement, 2, flag ? 1 : 0);
            sqlite3_bind_double(insertStatement, 3, NSTimeIntervalSince1970);
            if (sqlite3_step(insertStatement) == SQLITE_DONE) {
                NSLog(@"Successfully inserted row into table %@", tableName);
            } else {
                [self logSqlError:[NSString stringWithFormat:@"Failed to insert row into table %@", tableName]];
                [self recreate];
            }
        } else {
            [self logSqlError:[NSString stringWithFormat:@"INSERT statement for table %@ could not be prepared", tableName]];
            [self recreate];
        }
        sqlite3_finalize(insertStatement);
    } else {
        [self reconnect];
    }
}

- (void) deleteRows:(NSString *)persistenceType ids:(NSArray *)ids {
    if (_connection) {
        NSString *tableName = [self tableNameFor:persistenceType];
        NSString *fromString = ids ? [NSString stringWithFormat:@" WHERE id IN %@", [self idsSqlString: ids]] : @"";
        NSString *deleteString = [NSString stringWithFormat:@"DELETE FROM %@%@", tableName, fromString];
        sqlite3_stmt *deleteStatement;
        if (sqlite3_prepare_v2(_connection, [deleteString UTF8String], -1, &deleteStatement, nil) == SQLITE_OK) {
            if (sqlite3_step(deleteStatement) == SQLITE_DONE) {
                NSLog(@"Successfully deleted rows from table %@", tableName);
            } else {
                [self logSqlError:[NSString stringWithFormat:@"Failed to delete rows from table %@", tableName]];
                [self recreate];
            }
        } else {
            [self logSqlError:[NSString stringWithFormat:@"DELETE statement for table %@ could not be preapred", tableName]];
            [self recreate];
        }
        sqlite3_finalize(deleteStatement);
    } else {
        [self reconnect];
    }
}

- (NSString *)idsSqlString:(NSArray *)ids {
    NSString *sqlString = @"(";
    for (NSNumber *eId in ids) {
        sqlString = [sqlString stringByAppendingString:[NSString stringWithFormat:@"%@,", eId]];
    }
    sqlString = [sqlString substringToIndex:[sqlString length] - 1];
    return [sqlString stringByAppendingString:@")"];
}

- (void) updateRowsFlag:(NSString *)persistenceType newFlag:(bool)newFlag {
    if (_connection) {
        NSString *tableName = [self tableNameFor:persistenceType];
        NSString *updateString = [NSString stringWithFormat:@"UPDATE %@ SET flag = %d where flag = %d", tableName, newFlag, !newFlag];
        sqlite3_stmt *updateStatement;
        if (sqlite3_prepare_v2(_connection, [updateString UTF8String], -1, &updateStatement, nil) == SQLITE_OK) {
            if (sqlite3_step(updateStatement) == SQLITE_DONE) {
                NSLog(@"Successfully updated rows in table %@", tableName);
            } else {
                [self logSqlError:[NSString stringWithFormat:@"Failed to update rows in table %@", tableName]];
                [self recreate];
            }
        } else {
            [self logSqlError:[NSString stringWithFormat:@"UPDATE statement for table %@ could not be prepared", tableName]];
            [self recreate];
        }
        sqlite3_finalize(updateStatement);
    } else {
        [self reconnect];
    }
}

- (NSArray *) readRows:(NSString *)persistenceType numRows:(int)numRows flag:(bool)flag {
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    if (_connection) {
        NSString *tableName = [self tableNameFor:persistenceType];
        NSString *limitString = (numRows == INT_MAX) ? @"" : [NSString stringWithFormat:@" LIMIT %d", numRows];
        NSString *selectString = [NSString stringWithFormat:@"SELECT id, data FROM %@ WHERE flag = %d ORDER BY time%@", tableName, flag, limitString];
        sqlite3_stmt *selectStatement;
        int rowsRead = 0;
        if (sqlite3_prepare_v2(_connection, [selectString UTF8String], -1, &selectStatement, nil) == SQLITE_OK) {
            while (sqlite3_step(selectStatement) == SQLITE_ROW) {
                NSData *blob = [[NSData alloc] initWithBytes: sqlite3_column_blob(selectStatement, 1) length: sqlite3_column_bytes(selectStatement, 1)];
                if (blob) {
                    int eId = sqlite3_column_int(selectStatement, 0);
                    NSError *error;
                    NSMutableDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:blob options:NSJSONReadingMutableContainers error:&error];
                    jsonObject[@"id"] = [NSNumber numberWithInt:eId];
                    [rows addObject:jsonObject];
                    rowsRead++;
                } else {
                    [self logSqlError:[NSString stringWithFormat:@"No blob found in data column for row in %@", tableName]];
                }
            }
            if (rowsRead > 0) {
                NSLog(@"Successfully read %d rows from table %@", rowsRead, tableName);
            }
        } else {
            [self logSqlError:[NSString stringWithFormat:@"SELECT statement for table %@ could not be prepared.", tableName]];
        }
        sqlite3_finalize(selectStatement);
    } else {
        [self reconnect];
    }
    return rows;
}

- (void) logSqlError:(NSString *)message {
    if (_connection) {
        if (message) {
            NSLog(@"%@", message);
        }
        NSString *sqlError = [NSString stringWithCString:sqlite3_errmsg(_connection) encoding:NSUTF8StringEncoding];
        NSLog(@"%@", sqlError);
    } else {
        [self reconnect];
    }
}

@end
