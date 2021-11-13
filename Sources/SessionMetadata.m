//
//  SessionMetadata.m
//  Mixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import "SessionMetadata.h"

@interface SessionMetadata()

@property (nonatomic, readwrite) uint64_t eventsCounter;
@property (nonatomic, readwrite) uint64_t peopleCounter;
@property (nonatomic, readwrite, copy) NSString *sessionID;
@property (nonatomic, readwrite) uint64_t sessionStartEpoch;

@end

@implementation SessionMetadata

- (instancetype)init {
    self = [super init];
    if (self) {
        self.eventsCounter = 0;
        self.peopleCounter = 0;
        self.sessionID = [self randomId];
        self.sessionStartEpoch = (uint64_t)[[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (void)reset {
    self.eventsCounter = 0;
    self.peopleCounter = 0;
    self.sessionID = [self randomId];
    self.sessionStartEpoch = (uint64_t)[[NSDate date] timeIntervalSince1970];
}

- (NSString *)randomId {
    return [NSString stringWithFormat:@"%08x%08x", arc4random(), arc4random()];
}

- (NSDictionary *)toDictionaryForEvent:(BOOL)flag {
    NSDictionary *dict = @{@"$mp_metadata":@{@"$mp_event_id": [self randomId],
                                             @"$mp_session_id":self.sessionID,
                                             @"$mp_session_seq_id": [NSNumber numberWithUnsignedLongLong: (flag ? self.eventsCounter : self.peopleCounter)],
                                             @"$mp_session_start_sec": [NSNumber numberWithUnsignedLongLong:self.sessionStartEpoch]}};
    flag ? (self.eventsCounter += 1) : (self.peopleCounter += 1);
    return dict;
}

@end
