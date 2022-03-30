

[![Build Status](https://travis-ci.org/mixpanel/mixpanel-iphone.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-iphone)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Percentage of issues still open")
[![CocoaPods Version](http://img.shields.io/cocoapods/v/Mixpanel.svg?style=flat)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel.svg?style=flat)](https://mixpanel.com)

# Table of Contents

<!-- MarkdownTOC -->

- [Overview](#overview)
- [Quick Start Guide](#quick-start-guide)
    - [Install Mixpanel](#1-install-mixpanel)
    - [Initialize Mixpanel](#2-initialize-mixpanel)
    - [Send Data](#3-send-data)
    - [Check for Success](#4-check-for-success)
    - [Complete Code Example](#complete-code-example)
- [FAQ](#faq)
- [I want to know more!](#i-want-to-know-more)

<!-- /MarkdownTOC -->

<a name="introduction"></a>
# Overview

The Mixpanel library for iOS is an open source project, and we'd love to see your contributions! We'd also love for you to come and work with us! Check out https://mixpanel.com/jobs/#openings for details.
If you are using Swift, we recommend our **[Swift Library](https://github.com/mixpanel/mixpanel-swift)**.

Check out our [Advanced iOS - Objective-C Guide](https://developer.mixpanel.com/docs/ios) for additional advanced configurations and use cases, like setting up your project with European Union data storage.

[Skip to a complete code example](#complete-code-example).


# Quick Start Guide
Caution: From v4.0.0.beta.3 to v4.1.0, we have a bug that events with ampersand(&) will be rejected by the server. We recommend you update to v4.1.1 or above.

## 1. Install Mixpanel
You can install the Mixpanel iOS - Objective-C library by using CocoaPods or Carthage. You will need your project token for initializing your library. You can get your project token from [project settings](https://mixpanel.com/settings/project).

### Installation Option 1: CocoaPods
1. If this is your first time using CocoaPods, Install CocoaPods using `gem install cocoapods`. Otherwise, continue to Step 3.
2. Run `pod setup` to create a local CocoaPods spec mirror.
3. Create a Podfile in your Xcode project directory by running `pod init` in your terminal, edit the Podfile generated, and add the following line: `pod 'Mixpanel'`.
4. Run `pod install` in your Xcode project directory. CocoaPods should download and install the Mixpanel library, and create a new Xcode workspace. Open up this workspace in Xcode or typing `open *.xcworkspace` in your terminal.

### Installation Option 2: Carthage
Mixpanel supports Carthage to package your dependencies as a framework. Include the following dependency in your Cartfile:
```objc
github "mixpanel/mixpanel-iphone"
```
Check out the [Carthage docs](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos) for more info.

### Installation Option 3: Swift Package Manager
1.  In Xcode, select File > Add Packages...
2.  Enter the package URL for this [repository](https://github.com/mixpanel/mixpanel-iphone) and must select a version greater than or equal to v4.0.0

## 2. Initialize Mixpanel
To initialize the library, add `#Import "Mixpanel/Mixpanel.h" into "AppDelegate.m" and call [sharedInstanceWithToken:](https://mixpanel.github.io/mixpanel-iphone/Classes/Mixpanel.html#//api/name/sharedInstanceWithToken:) with your project token as its argument in [application:didFinishLaunchingWithOptions:](https://developer.apple.com/documentation/uikit/uiapplicationdelegate#//apple_ref/occ/intfm/UIApplicationDelegate/application:willFinishLaunchingWithOptions:).
```objc
#import "Mixpanel/Mixpanel.h"

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
...
  [Mixpanel sharedInstanceWithToken:@"YOUR_API_TOKEN"];
...
}
```
[See all configuration options](https://mixpanel.github.io/mixpanel-iphone/Classes/Mixpanel.html)

## 3. Send Data
Let's get started by sending event data. You can send an event from anywhere in your application. Better understand user behavior by storing details that are specific to the event (properties). After initializing the library, Mixpanel will [automatically collect common mobile events](https://mixpanel.com/help/questions/articles/which-common-mobile-events-can-mixpanel-collect-on-my-behalf-automatically). You can enable/disable automatic collection through your [project settings](https://help.mixpanel.com/hc/en-us/articles/115004596186#enable-or-disable-common-mobile-events). Also, Mixpanel automatically tracks some properties by default. [learn more](https://help.mixpanel.com/hc/en-us/articles/115004613766-Default-Properties-Collected-by-Mixpanel#iOS)

```objc
Mixpanel *mixpanel = [Mixpanel sharedInstance];
[mixpanel track:@"Sign Up" properties:@{
  @"source": @"Pat's affiliate site",
  @"Opted out of email": @YES
}];
```

## 4. Check for Success
[Open up Live View in Mixpanel](http://mixpanel.com/report/live) to view incoming events. 

Once data hits our API, it generally takes ~60 seconds for it to be processed, stored, and queryable in your project.

## Complete Code Example
Here's a runnable code example that covers everything in this quickstart guide.
```objc
#import "Mixpanel/Mixpanel.h"

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
...
  Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"YOUR_API_TOKEN"];
  [mixpanel track:@"Sign Up" properties:@{
    @"source": @"Pat's affiliate site",
    @"Opted out of email": @YES
  }];
...
}
```

# FAQ
**I want to stop tracking an event/event property in Mixpanel. Is that possible?**

Yes, in Lexicon, you can intercept and drop incoming events or properties. Mixpanel won’t store any new data for the event or property you select to drop. [See this article for more information](https://help.mixpanel.com/hc/en-us/articles/360001307806#dropping-events-and-properties).

**I have a test user I would like to opt out of tracking. How do I do that?**

Mixpanel’s client-side tracking library contains the [optOutTracking()](https://mixpanel.github.io/mixpanel-iphone/Classes/Mixpanel.html#//api/name/optOutTracking) method, which will set the user’s local opt-out state to “true” and will prevent data from being sent from a user’s device. More detailed instructions can be found in the section, [Opting users out of tracking](ios#opting-users-out-of-tracking).

**Why aren't my events showing up?**

To preserve battery life and customer bandwidth, the Mixpanel library doesn't send the events you record immediately. Instead, it sends batches to the Mixpanel servers every 60 seconds while your application is running, as well as when the application transitions to the background. You can call [flush()](https://mixpanel.github.io/mixpanel-iphone/Classes/Mixpanel.html#//api/name/flush) manually if you want to force a flush at a particular moment.

```objc
[mixpanel flush];
```
If your events are still not showing up after 60 seconds, check if you have opted out of tracking. You can also enable Mixpanel debugging and logging, it allows you to see the debug output from the Mixpanel library. To enable it, set [enableLogging](https://mixpanel.github.io/mixpanel-iphone/Classes/Mixpanel.html#//api/name/enableLogging) to true.

```objc
mixpanel.enableLogging = YES;
```

**Starting with iOS 14.5, do I need to request the user’s permission through the AppTrackingTransparency framework to use Mixpanel?**

No, Mixpanel does not use IDFA so it does not require user permission through the AppTrackingTransparency(ATT) framework.

**If I use Mixpanel, how do I answer app privacy questions for the App Store?**

Please refer to our [Apple App Developer Privacy Guidance](https://mixpanel.com/legal/app-store-privacy-details/)

## I want to know more!

No worries, here are some links that you will find useful:
* **[Advanced iOS - Objective-C Guide](https://developer.mixpanel.com/docs/ios)**
* **[Sample app](https://github.com/mixpanel/mixpanel-iphone/tree/master/HelloMixpanel)**
* **[Full API Reference](https://mixpanel.github.io/mixpanel-iphone/index.html)**

Have any questions? Reach out to Mixpanel [Support](https://help.mixpanel.com/hc/en-us/requests/new) to speak to someone smart, quickly.
