[![Build Status](https://travis-ci.org/mixpanel/mixpanel-iphone.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-iphone)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-iphone.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-iphone "Percentage of issues still open")
[![CocoaPods Version](http://img.shields.io/cocoapods/v/Mixpanel.svg?style=flat)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel.svg?style=flat)](https://mixpanel.com)

**Want to Contribute?**

The Mixpanel library for iOS is an open source project, and we'd love to see your contributions! We'd also love for you to come and work with us! Check out http://boards.greenhouse.io/mixpanel/jobs/25226#.U_4JXEhORKU for details.

If you are using Swift, we recommend our **[Swift Library](https://github.com/mixpanel/mixpanel-swift)** (currently supports the tracking and people API).

# Installation

## CocoaPods

Mixpanel supports `CocoaPods` for easy installation.
To Install, see our **[full documentation »](https://mixpanel.com/help/reference/ios)**

#### iOS: 
`pod 'Mixpanel'`
#### tvOS:
`pod 'Mixpanel/tvOS'`
#### watchOS:
`pod 'Mixpanel'`
#### App Extension:
`pod 'Mixpanel-AppExtension'`

## Carthage

Mixpanel also supports `Carthage` to package your dependencies as a framework.
Check out the **[Carthage docs »](https://github.com/Carthage/Carthage)** for more info.

To integrate Mixpanel into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "mixpanel/mixpanel-iphone"
```

Run `carthage update` to build the framework and drag the built `Mixpanel.framework` into your Xcode project.

## Manual Installation

To help users stay up to date with the latests version of our iOS SDK, we always recommend integrating our SDK via CocoaPods, which simplifies version updates and dependency management. However, there are cases where users can't use CocoaPods. Not to worry, just follow these manual installation steps and you'll be all set.

### Step 1: Add as a Submodule

Add Mixpanel as a submodule to your local git repo like so:

```
git submodule add git@github.com:mixpanel/mixpanel-iphone.git
```

Now the Mixpanel project and its files should be in your project folder!

### Step 2: Add the SDK to your app!

Add the "Mixpanel" folder from the "mixpanel-iphone" to your Xcode project's folder:

![alt text](http://images.mxpnl.com/blog/2014-09-24%2000:56:07.905215-SprityBird_and_mixpanel-iphone.png)

And drag and drop the Mixpanel folder into your Xcode Project Workspace:

![alt text](http://images.mxpnl.com/blog/2014-09-24%2001:08:51.474250-AppDelegate_m_and_SprityBird.png)

### Step 3: Import All dependencies

Add all dependencies of the Mixpanel SDK to your app. The full list of necessary frameworks and libraries on lines 16-17 in the "Mixpanel.podspec" file in the "mixpanel-iphone" directory: 

![alt text](http://images.mxpnl.com/blog/2014-09-24%2001:32:27.445697-1__vim_and_spritybird_and_Mixpanel_-_Agent_and_spritybird.png)

## Step 4: Integrate!

Import "Mixpanel.h" into AppDelegate.m, and initialize Mixpanel within `application:didFinishLaunchingWithOptions:`

![alt text](http://images.mxpnl.com/blog/2014-09-24%2001:19:19.598858-AppDelegate_m.png)

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
}
```

## Start tracking

You're done! You've successfully integrated the Mixpanel SDK into your app. To stay up to speed on important SDK releases and updates watch our iPhone repository on [Github](https://github.com/mixpanel/mixpanel-iphone).

Have any questions? Reach out to [support@mixpanel.com](mailto:support@mixpanel.com) to speak to someone smart, quickly.
