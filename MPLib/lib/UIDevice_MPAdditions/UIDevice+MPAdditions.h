#import <UIKit/UIDevice.h>

extern NSString* const UIDeviceMPConnectivityNone;
extern NSString* const UIDeviceMPConnectivityCellular;
extern NSString* const UIDeviceMPConnectivityWiFi;

@interface UIDevice(MPAdditions)
-(NSString*)model;
-(NSString*)connectivity;
@end
