//
//  Mixpanel_Testing.h
//  HelloMixpanel
//
//  Created by Sam Green on 6/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import <Nocilla/Nocilla.h>

#pragma mark - Constants
static NSString *const kTestToken = @"abc123";
static NSString *const kDefaultServerString = @"https://api.mixpanel.com";
static NSString *const kDefaultServerTrackString = @"https://api.mixpanel.com/track/";
static NSString *const kDefaultServerEngageString = @"https://api.mixpanel.com/engage/";
static NSString *const kDefaultServerGroupsString = @"https://api.mixpanel.com/groups/";

#pragma mark - Stub Helpers
static inline LSStubRequestDSL *stubEngage() {
    return stubRequest(@"POST", kDefaultServerEngageString).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubTrack() {
    return stubRequest(@"POST", kDefaultServerTrackString).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubGroups() {
    return stubRequest(@"POST", kDefaultServerGroupsString).withHeader(@"Accept-Encoding", @"gzip");
}
