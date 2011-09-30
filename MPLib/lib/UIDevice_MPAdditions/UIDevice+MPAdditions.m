#import "UIDevice+MPAdditions.h"

#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>

NSString* const UIDeviceMPConnectivityNone = @"none";
NSString* const UIDeviceMPConnectivityCellular = @"cellular";
NSString* const UIDeviceMPConnectivityWiFi = @"wifi";

@implementation UIDevice(MPAdditions)

-(NSString*)model {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
    free(machine);
    return platform;
}


-(NSString*)connectivity {
    // Create zero address
    struct sockaddr_in sockAddr;
    bzero(&sockAddr, sizeof(sockAddr));
    sockAddr.sin_len = sizeof(sockAddr);
    sockAddr.sin_family = AF_INET;
    
    // Recover reachability flags
    SCNetworkReachabilityRef nrRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&sockAddr);
    SCNetworkReachabilityFlags flags;
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(nrRef, &flags);
    if (!didRetrieveFlags) {
        ZTLog(@"Unable to fetch the network reachablity flags");
    }
    
    CFRelease(nrRef);
    
    if (!didRetrieveFlags || (flags & kSCNetworkReachabilityFlagsReachable) != kSCNetworkReachabilityFlagsReachable)
        // Unable to connect to a network (no signal or airplane mode activated)
        return UIDeviceMPConnectivityNone;
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
        // Only a cellular network connection is available.
        return UIDeviceMPConnectivityCellular;
    
    // WiFi connection available.
    return UIDeviceMPConnectivityWiFi;
}

@end