//
//  Mixpanel_Testing.h
//  HelloMixpanel
//
//  Copyright © Mixpanel. All rights reserved.
//

#import <Nocilla/Nocilla.h>

#pragma mark - Constants
static NSString *const kTestToken = @"abc123";
static NSString *const kDefaultServerString = @"https://api.mixpanel.com";

#pragma mark - Stub Helpers
static inline LSStubRequestDSL *stubEngage() {
    return stubRequest(@"POST", @"https://api.mixpanel.com/engage/".regex).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubTrack() {
    return stubRequest(@"POST", @"https://api.mixpanel.com/track/".regex).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubGroups() {
    return stubRequest(@"POST", @"https://api.mixpanel.com/groups/".regex).withHeader(@"Accept-Encoding", @"gzip");
}

static inline LSStubRequestDSL *stubDecide() {
    return stubRequest(@"POST", @"https://api.mixpanel.com/decide(.*?)".regex).withHeader(@"Accept-Encoding", @"gzip");
}

