#import "MPDeviceNamer.h"

@implementation MPDeviceNamer
+(NSString *)readableNameWithDeviceName:(NSString *)deviceName 
{
    NSString *readableName = nil;

    if ([deviceName isEqualToString:@"iPhone1,1"])         readableName = @"iPhone 1G";
    else if ([deviceName isEqualToString:@"iPhone1,2"])    readableName = @"iPhone 3G";
    else if ([deviceName isEqualToString:@"iPhone2,1"])    readableName = @"iPhone 3GS";
    else if ([deviceName isEqualToString:@"iPhone3,1"])    readableName = @"iPhone 4";
    else if ([deviceName isEqualToString:@"iPhone3,3"])    readableName = @"Verizon iPhone 4";
    else if ([deviceName isEqualToString:@"iPhone4,1"])    readableName = @"iPhone 4S";
    else if ([deviceName isEqualToString:@"iPhone5,1"])    readableName = @"iPhone 5 (GSM)";
    else if ([deviceName isEqualToString:@"iPhone5,2"])    readableName = @"iPhone 5 (GSM+CDMA)";
    else if ([deviceName isEqualToString:@"iPhone5,3"])    readableName = @"iPhone 5c (GSM)";
    else if ([deviceName isEqualToString:@"iPhone5,4"])    readableName = @"iPhone 5c (Global)";
    else if ([deviceName isEqualToString:@"iPhone6,1"])    readableName = @"iPhone 5s (GSM)";
    else if ([deviceName isEqualToString:@"iPhone6,2"])    readableName = @"iPhone 5s (Global)";
    else if ([deviceName isEqualToString:@"iPod1,1"])      readableName = @"iPod Touch 1G";
    else if ([deviceName isEqualToString:@"iPod2,1"])      readableName = @"iPod Touch 2G";
    else if ([deviceName isEqualToString:@"iPod3,1"])      readableName = @"iPod Touch 3G";
    else if ([deviceName isEqualToString:@"iPod4,1"])      readableName = @"iPod Touch 4G";
    else if ([deviceName isEqualToString:@"iPod5,1"])      readableName = @"iPod Touch 5G";
    else if ([deviceName isEqualToString:@"iPad1,1"])      readableName = @"iPad";
    else if ([deviceName isEqualToString:@"iPad2,1"])      readableName = @"iPad 2 (WiFi)";
    else if ([deviceName isEqualToString:@"iPad2,2"])      readableName = @"iPad 2 (GSM)";
    else if ([deviceName isEqualToString:@"iPad2,3"])      readableName = @"iPad 2 (CDMA)";
    else if ([deviceName isEqualToString:@"iPad2,4"])      readableName = @"iPad 2 (WiFi)";
    else if ([deviceName isEqualToString:@"iPad2,5"])      readableName = @"iPad Mini (WiFi)";
    else if ([deviceName isEqualToString:@"iPad2,6"])      readableName = @"iPad Mini (GSM)";
    else if ([deviceName isEqualToString:@"iPad2,7"])      readableName = @"iPad Mini (GSM+CDMA)";
    else if ([deviceName isEqualToString:@"iPad3,1"])      readableName = @"iPad 3 (WiFi)";
    else if ([deviceName isEqualToString:@"iPad3,2"])      readableName = @"iPad 3 (GSM+CDMA)";
    else if ([deviceName isEqualToString:@"iPad3,3"])      readableName = @"iPad 3 (GSM)";
    else if ([deviceName isEqualToString:@"iPad3,4"])      readableName = @"iPad 4 (WiFi)";
    else if ([deviceName isEqualToString:@"iPad3,5"])      readableName = @"iPad 4 (GSM)";
    else if ([deviceName isEqualToString:@"iPad3,6"])      readableName = @"iPad 4 (GSM+CDMA)";
    else if ([deviceName isEqualToString:@"iPad4,1"])      readableName = @"iPad Air (WiFi)";
    else if ([deviceName isEqualToString:@"iPad4,2"])      readableName = @"iPad Air (GSM)";
    else if ([deviceName isEqualToString:@"iPad4,4"])      readableName = @"iPad Mini Retina (WiFi)";
    else if ([deviceName isEqualToString:@"iPad4,5"])      readableName = @"iPad Mini Retina (GSM)";
    else if ([deviceName isEqualToString:@"i386"])         readableName = @"Simulator";
    else if ([deviceName isEqualToString:@"x86_64"])       readableName = @"Simulator";
    else readableName = name

    return readableName;
}
@end