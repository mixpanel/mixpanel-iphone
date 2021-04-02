
[![Build Status](https://travis-ci.org/mixpanel/mixpanel-iphone.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-iphone)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Percentage of issues still open")
[![CocoaPods Version](http://img.shields.io/cocoapods/v/Mixpanel.svg?style=flat)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel.svg?style=flat)](https://mixpanel.com)

# Table of Contents

<!-- MarkdownTOC -->

- [Introduction](#introduction)
- [Installation](#installation)
    - [CocoaPods](#cocoapods)
    - [Carthage](#carthage)
    - [Manual Installation](#manual-installation)
- [Integrate](#integrate)
- [Start tracking](#start-tracking)

<!-- /MarkdownTOC -->

<a name="introduction"></a>
# Introduction

The Mixpanel library for iOS is an open source project, and we'd love to see your contributions! We'd also love for you to come and work with us! Check out https://mixpanel.com/jobs/#openings for details.

If you are using Swift, we recommend our **[Swift Library](https://github.com/mixpanel/mixpanel-swift)**.

<a name="installation"></a>
# Installation
On Jan 1, 2022, we’ll remove the [Messages & Experiments](https://mixpanel.com/blog/why-were-sunsetting-messaging-and-experiments/#:~:text=A%20year%20from%20now%2C%20on,offering%20discounts%20for%20getting%20started) feature from Mixpanel. For now, you can choose to opt in to our beta version without Messages & Experiments feature support. You can use **Swift Package Manager** to install the beta version:
1.  In Xcode, select File > Swift Packages > Add Package Dependency.
2.  Follow the prompts using the URL for this repository and point to the branch `4.0.0.beta`

<a name="cocoapods"></a>
## CocoaPods

Mixpanel supports `CocoaPods` for easy installation.
To Install, see our **[full documentation »](https://mixpanel.com/help/reference/ios)**

#### iOS, tvOS, watchOS, macOS: 
`pod 'Mixpanel'`

<a name="carthage"></a>
## Carthage

Mixpanel also supports `Carthage` to package your dependencies as a framework.
Check out the **[Carthage docs »](https://github.com/Carthage/Carthage)** for more info.

To integrate Mixpanel into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "mixpanel/mixpanel-iphone"
```

Run `carthage update` to build the framework and drag the built `Mixpanel.framework` into your Xcode project.

<a name="manual-installation"></a>
## Manual Installation

To help users stay up to date with the latests version of our iOS SDK, we always recommend integrating our SDK via CocoaPods, which simplifies version updates and dependency management. However, there are cases where users can't use CocoaPods. Not to worry, just follow these manual installation steps and you'll be all set.

### Step 1: Add as a submodule

Add Mixpanel as a submodule to your local git repo like so:

```
git submodule add git@github.com:mixpanel/mixpanel-iphone.git
```

Now the Mixpanel project and its files should be in your project folder!

### Step 2: Add the SDK to your app!

Drag and drop Mixpanel.xcodeproj from the mixpanel-iphone folder into your Xcode Project Workspace:

![alt text](http://i.imgur.com/6qgxEBY.png)

### Step 3: Embed the Mixpanel framework

Select your app .xcodeproj file. Under "General", add the Mixpanel framework as an embedded binary. Once added, please make sure `Mixpanel.framework` shows under both "Linked Frameworks and Libaries" and "Embedded Binaries".


<a name="integrate"></a>
# Integrate

Import <Mixpanel/Mixpanel.h> into AppDelegate.m, and initialize Mixpanel within `application:didFinishLaunchingWithOptions:`

```objective-c
#import "AppDelegate.h"
#import <Mixpanel/Mixpanel.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
}
```

You initialize your Mixpanel instance with the token provided to you on mixpanel.com.

<a name="start-tracking"></a>
# Start tracking

After installing the library into your iOS app, Mixpanel will <a href="https://mixpanel.com/help/questions/articles/which-common-mobile-events-can-mixpanel-collect-on-my-behalf-automatically" target="_blank">automatically collect common mobile events</a>. You can enable/ disable automatic collection through your <a href="https://mixpanel.com/help/questions/articles/how-do-i-enable-common-mobile-events-if-i-have-already-implemented-mixpanel" target="_blank">project settings</a>.

Tracking additional events is as easy as adding `track:` or `track:properties:` anywhere after initializing Mixpanel.

```objective-c
[[Mixpanel sharedInstance] track:@"Event name"];
[[Mixpanel sharedInstance] track:@"Event name" properties:@{@"Prop name": @"Prop value"}];
```

You're done! You've successfully integrated the Mixpanel SDK into your app. To stay up to speed on important SDK releases and updates watch our iPhone repository on [Github](https://github.com/mixpanel/mixpanel-iphone).

Have any questions? Reach out to [support@mixpanel.com](mailto:support@mixpanel.com) to speak to someone smart, quickly.


## Using Mixpanel Push Notifications

First [enable Mixpanel push notifications in your app](https://developer.mixpanel.com/docs/ios-push-notifications). Then for Rich Push Notifications, you'll need to integrate your application with the MixpanelNotificationServiceExtension.

### Integrating the MixpanelNotificationServiceExtension

The Mixpanel SDK comes with a custom [Notification Service Extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension?language=objc) used to render rich media, custom action buttons, and track when push notifications are received. In order to enable these features, you will need to integrate it into your application.

#### 1. Create a new Notification Service Extension Target
<img width="739" alt="Screenshot 2020-02-13 14 46 53" src="https://user-images.githubusercontent.com/556882/74483322-df266200-4e7b-11ea-97ad-01f145fa5613.png">
<img width="738" alt="Screenshot 2020-02-13 14 44 38" src="https://user-images.githubusercontent.com/556882/74478475-0c224700-4e73-11ea-9f57-3b40b6fdbbcd.png">
<img width="739" alt="Screenshot 2020-02-13 14 46 53" src="https://user-images.githubusercontent.com/556882/74483383-febd8a80-4e7b-11ea-9421-ad5005e670f8.png">

#### 2. Add Mixpanel as a dependency
Add the following to the end of your `Podfile`:
```Podspec
target 'NotificationService' do
  use_frameworks!
  
  pod 'Mixpanel'
end
```
Then run `pod install`


#### 3. Extend your NotificationService from MixpanelNotificationServiceExtension
Replace the contents of your `NotificationService.h` file with the following:
```objective-c
@import Mixpanel;

@interface NotificationService : MPNotificationServiceExtension

@end
```

Replace the contents of your `NotificationService.m` file with the following:
```objective-c
#import "NotificationService.h"

@implementation NotificationService

@end
```

#### 4. Delegate the handling of the notification response to the Mixpanel SDK
In your `AppDelegate.m` file:
```objc
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    if ([Mixpanel isMixpanelPushNotification:response.notification.request.content]) {
        NSLog(@"%@ delegating to Mixpanel SDK handler to handle push notification response...", self);
        [Mixpanel userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
    } else {
        NSLog(@"%@ Not a Mixpanel push notification....", self);
        completionHandler();
    }
}
```
This will make sure the tap actions are appropriately handled (open url, deeplink, etc) as well as track whether a notification was tapped or dismissed.

#### 5. Run the app and send a test push notification from Mixpanel that includes an image or buttons

That's it! Your app should now be able to receive rich push notifications from Mixpanel.
