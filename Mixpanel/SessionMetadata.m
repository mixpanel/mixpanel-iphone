//
//  SessionMetadata.m
//  Mixpanel
//
//  Created by Yarden Eitan on 10/27/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import "SessionMetadata.h"

@implementation SessionMetadata

- (instancetype)init {
    self = [super init];
    if (self) {
        self.eventsCounter = 0;
        self.peopleCounter = 0;
        self.sessionID = 0;
        self.sessionStartEpoch = (uint64_t)[[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (void)reset {
    self.eventsCounter = 0;
    self.peopleCounter = 0;
    self.sessionID = random();
    self.sessionStartEpoch = (uint64_t)[[NSDate date] timeIntervalSince1970];
}

+ (uint64_t)random {
    uint64_t num = 0;
    for (int i=0; i<2; i++) {
        num <<= 32;
        num |= arc4random();
    }
    return num;
}

- (NSDictionary *)toDictionaryForEvent:(BOOL)flag {
    NSDictionary *dict = @{@"$mp_event_id": [NSNumber numberWithUnsignedLongLong:random()],
                           @"$mp_session_id": [NSNumber numberWithUnsignedLongLong:self.sessionID],
                           @"$mp_session_seq_id": [NSNumber numberWithUnsignedLongLong: (flag ? self.eventsCounter : self.peopleCounter)],
                           @"$mp_session_start_sec": [NSNumber numberWithUnsignedLongLong:self.sessionStartEpoch]};
    flag ? (self.eventsCounter += 1) : (self.peopleCounter += 1);
    return dict;
}

@end
