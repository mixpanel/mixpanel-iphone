# This is a private and confidential repository

### Please review our [Terms of Service](https://mixpanel.com/terms/)

[![Build Status](https://travis-ci.org/mixpanel/mixpanel-iphone.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-iphone)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel.svg?style=flat)](https://mixpanel.com)


# Integration

Download the framework from the releases tab, and drag `Mixpanel.framework` in to your Xcode project. Please add the framework to "Embedded Binaries" as well, this will resolve a framework loading bug on iOS 9.2.1+

## Import All dependencies

* UIKit
* Foundation
* SystemConfiguration
* CoreTelephony
* Accelerate
* CoreGraphics
* QuartzCore

Add all dependencies of the Mixpanel SDK to your app. The full list of necessary frameworks and libraries on lines 16-17 in the "Mixpanel.podspec" file in the "mixpanel-iphone" directory: 

![alt text](http://images.mxpnl.com/blog/2014-09-24%2001:32:27.445697-1__vim_and_spritybird_and_Mixpanel_-_Agent_and_spritybird.png)

## Set up your token and initialize Mixpanel

Import "Mixpanel.h" into AppDelegate.m, and initialize Mixpanel within `application:didFinishLaunchingWithOptions:`

![alt text](http://images.mxpnl.com/blog/2014-09-24%2001:19:19.598858-AppDelegate_m.png)

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
}
```

## Start tracking

You're done! You've successfully integrated the Mixpanel SDK into your app. To stay up to speed on important SDK releases and updates, subscribe to the [mp-dev Google group](https://groups.google.com/forum/?fromgroups#!forum/mp-dev) or watch the iPhone repository on [Github](https://github.com/mixpanel/mixpanel-iphone).

Have any questions? Reach out to [support@mixpanel.com](mailto:support@mixpanel.com) to speak to someone smart, quickly.
