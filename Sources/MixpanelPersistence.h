//
//  MixpanelPersistence.h
//  Mixpanel
//
//  Created by Jared McFarland on 10/1/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

#ifndef MixpanelPersistence_h
#define MixpanelPersistence_h

#import <Foundation/Foundation.h>
#import "MPDB.h"

@interface MixpanelPersistence : NSObject {
    NSString *_apiToken;
    MPDB *_mpdb;
}

@property (nonatomic, copy) NSString *apiToken;
@property (nonatomic, copy) MPDB *mpdb;

- (instancetype)initWithToken:(NSString *)token;

@end

#endif /* MixpanelPersistence_h */
