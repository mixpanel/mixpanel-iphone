//
//  AppDelegate.h
//  MixpanelEventSampleCocoa
//
//

#import <Cocoa/Cocoa.h>

@class MixpanelAPI;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSButton *createUserButton;
    IBOutlet NSMatrix *genderMatrix;
    IBOutlet NSMatrix *weaponMatrix;

    MixpanelAPI *mixpanel;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *createUserButton;
@property (assign) IBOutlet NSMatrix *genderMatrix;
@property (assign) IBOutlet NSMatrix *weaponMatrix;

- (IBAction)didClickCreateUser:(id)sender;

@end
