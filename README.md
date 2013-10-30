# Mixpanel iOS library #

## Getting started ##

The easiest way to set up Mixpanel in your iOS project is to use [CocoaPods](http://cocoapods.org/).

1. Install cocoapods with `gem install cocoapods`
2. Create a file in your XCode project called `Podfile` and add the following line:
        
        pod 'Mixpanel'
        
3. Run `pod install` in your xcode project directory. CocoaPods should download and
install the Mixpanel library, and create a new Xcode workspace. Open up this workspace in Xcode.
4. Add the following line to `application:didFinishLaunchingWithOptions` in your `AppDelegate.m`.

        - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
            ...
            [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
            ...
        }

5. Track an event in your application.

        [[Mixpanel sharedInstance] track:@"Clicked Button"];

# Further Documentation #
1. [Events iOS Library Documentation](https://mixpanel.com/docs/integration-libraries/iphone)
2. [People iOS Library Documentation](https://mixpanel.com/docs/people-analytics/iphone)
3. [Full Headerdoc API Reference](https://mixpanel.com/site_media/doctyl/uploads/iPhone-spec/Classes/Mixpanel/index.html)

[copy]: https://raw.github.com/mixpanel/mixpanel-iphone/master/Docs/Images/copy.png "Copy"
[project]: https://raw.github.com/mixpanel/mixpanel-iphone/master/Docs/Images/project.png "Project"
