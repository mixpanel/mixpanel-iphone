[![Build Status](https://travis-ci.org/mixpanel/mixpanel-iphone.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-iphone)

**Quick start**

1. Install
  - With CocoaPods
    1. [CocoaPods](http://cocoapods.org/) with `gem install cocoapods`.
    2. Create a file in your XCode project called `Podfile` and add the following line:

        pod 'Mixpanel'

    3. Run `pod install` in your xcode project directory. CocoaPods should download and
install the Mixpanel library, and create a new Xcode workspace. Open up this workspace in Xcode.
  - With Git Submodules
    1. Run `git submodule add --init git@github.com:mixpanel/mixpanel-iphone.git` from whichever git repository you want to add Mixpanel to.
    2. Add the Xcode project for Mixpanel to your Xcode project.
    3. Add the CoreTelephony and SystemConfiguration frameworks to the Link Binaries with Libraries build phase of your targets.
2. Import Mixpanel in your App Delegate

        #import <Mixpanel/Mixpanel.h>

3. Configure Shared Instance with Your Token

        - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
            [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
        }

4. Start tracking actions in your app:

        [[Mixpanel sharedInstance] track:@"Watched video" properties:@{@"duration": @53}];

**Check out the [full documentation »](https://mixpanel.com/help/reference/ios)**
