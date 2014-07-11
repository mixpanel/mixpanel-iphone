//
// Copyright (c) 2014 Mixpanel. All rights reserved.

#import "MPABTestDesignerDeviceInfoRequestMessage.h"
#import "MPABTestDesignerDeviceInfoResponseMessage.h"
#import "MPABTestDesignerConnection.h"

// Facebook Tweaks
#import "MPTweakStore.h"
#import "MPTweakCollection.h"
#import "MPTweakCategory.h"
#import "MPTweak.h"

NSString *const MPABTestDesignerDeviceInfoRequestMessageType = @"device_info_request";

@implementation MPABTestDesignerDeviceInfoRequestMessage

+ (instancetype)message
{
    return [[self alloc] initWithType:MPABTestDesignerDeviceInfoRequestMessageType];
}

- (NSOperation *)responseCommandWithConnection:(MPABTestDesignerConnection *)connection
{
    __weak MPABTestDesignerConnection *weak_connection = connection;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MPABTestDesignerConnection *conn = weak_connection;

        MPABTestDesignerDeviceInfoResponseMessage *deviceInfoResponseMessage = [MPABTestDesignerDeviceInfoResponseMessage message];

        dispatch_sync(dispatch_get_main_queue(), ^{
            UIDevice *currentDevice = [UIDevice currentDevice];

            deviceInfoResponseMessage.systemName = currentDevice.systemName;
            deviceInfoResponseMessage.systemVersion = currentDevice.systemVersion;
            deviceInfoResponseMessage.deviceName = currentDevice.name;
            deviceInfoResponseMessage.deviceModel = currentDevice.model;
            deviceInfoResponseMessage.appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
            deviceInfoResponseMessage.appRelease = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
            deviceInfoResponseMessage.mainBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
            deviceInfoResponseMessage.availableFontFamilies = [self availableFontFamilies];
            deviceInfoResponseMessage.tweaks = [self getFacebookTweaks];
        });

        [conn sendMessage:deviceInfoResponseMessage];
    }];

    return operation;
}

- (NSArray *)availableFontFamilies
{
    NSMutableDictionary *fontFamilies = [[NSMutableDictionary alloc] init];

    // Get all the font families and font names.
    for (NSString *familyName in [UIFont familyNames])
    {
        fontFamilies[familyName] = [self fontDictionaryForFontFamilyName:familyName fontNames:[UIFont fontNamesForFamilyName:familyName]];
    }

    // For the system fonts update the font families.
    NSArray *systemFonts = @[[UIFont systemFontOfSize:17.0f],
            [UIFont boldSystemFontOfSize:17.0f],
            [UIFont italicSystemFontOfSize:17.0f]];

    for (UIFont *systemFont in systemFonts)
    {
        NSString *familyName = systemFont.familyName;
        NSString *fontName = systemFont.fontName;

        NSMutableDictionary *font = fontFamilies[familyName];
        if (font)
        {
            NSMutableArray *fontNames = font[@"font_names"];
            if ([fontNames containsObject:fontName] == NO)
            {
                [fontNames addObject:fontName];
            }
        }
        else
        {
            fontFamilies[familyName] = [self fontDictionaryForFontFamilyName:familyName fontNames:@[fontName]];
        }
    }

    return [fontFamilies allValues];
}

- (NSMutableDictionary *)fontDictionaryForFontFamilyName:(NSString *)familyName fontNames:(NSArray *)fontNames
{
    return [@{
        @"family" : familyName,
        @"font_names" : [fontNames mutableCopy]
    } mutableCopy];
}

- (NSArray *) getFacebookTweaks
{
    NSMutableArray *tweaks = [NSMutableArray array];
    NSArray *categories = [MPTweakStore sharedInstance].tweakCategories;
    for (MPTweakCategory *tcat in categories) {
        for (MPTweakCollection *tcol in tcat.tweakCollections) {
            for (MPTweak *t in tcol.tweaks) {
                [tweaks addObject:@{@"category": tcat.name,
                                    @"collection": tcol.name,
                                    @"tweak": t.name,
                                    @"identifier": t.identifier,
                                    @"default": t.defaultValue ?: [NSNull null],
                                    @"minimum": t.minimumValue ?: [NSNull null],
                                    @"maximum": t.maximumValue ?: [NSNull null],
                                    }];
            }
        }
    }
    return [tweaks copy];
}

@end
