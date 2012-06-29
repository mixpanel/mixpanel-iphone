//
//  Unit_Tests.h
//  Unit Tests
//

#import <SenTestingKit/SenTestingKit.h>

#import "MixpanelAPI.h"
#import "MixpanelAPI_Private.h"
#import "MPCJSONSerializer.h"

#define MP_TEST_UPLOAD_INTERVAL 3
#define MP_TEST_TOKEN @"886377995387084ca48b4c7a1d6e1aa3"

@interface Unit_Tests : SenTestCase {
    MixpanelAPI *mp;
}

@end
