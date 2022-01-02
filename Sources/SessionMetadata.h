//
//  SessionMetadata.h
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SessionMetadata : NSObject

@property (nonatomic, readonly) uint64_t eventsCounter;
@property (nonatomic, readonly) uint64_t peopleCounter;
@property (nonatomic, readonly, copy) NSString *sessionID;
@property (nonatomic, readonly) uint64_t sessionStartEpoch;

- (instancetype)init;
- (void)reset;
- (NSDictionary *)toDictionaryForEvent:(BOOL)flag;

@end
