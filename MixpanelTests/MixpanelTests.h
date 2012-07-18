//
//  MixpanelTests.h
//  MixpanelTests
//
//  Created by Andrew Smith on 7/18/12.
//  Copyright (c) 2012 eGraphs. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "MixpanelAPI.h"
#import "MixpanelAPI_Private.h"
#import "MPCJSONSerializer.h"

#define MP_TEST_UPLOAD_INTERVAL 3
#define MP_TEST_TOKEN @"test token"

@interface MixpanelTests : SenTestCase {
    MixpanelAPI *mp;
}

@end
