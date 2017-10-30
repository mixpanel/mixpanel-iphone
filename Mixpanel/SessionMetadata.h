//
//  SessionMetadata.h
//  Mixpanel
//
//  Created by Yarden Eitan on 10/27/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SessionMetadata : NSObject
    @property (nonatomic) uint64_t eventsCounter;
    @property (nonatomic) uint64_t peopleCounter;
    @property (nonatomic) uint64_t sessionID;
    @property (nonatomic) uint64_t sessionStartEpoch;
    @property (nonatomic) dispatch_queue_t trackingQueue;

    - (instancetype)init;
    - (void)reset;
    - (NSDictionary *)toDictionaryForEvent:(BOOL)flag;
@end
