# Alooma-iOS - an iOS Event Tracking Library

[![CI Status](http://img.shields.io/travis/Aloomaio/iossdk.svg?style=flat)](https://travis-ci.org/Alooma/Alooma-iOS)
[![Version](https://img.shields.io/cocoapods/v/Alooma-iOS.svg?style=flat)](http://cocoapods.org/pods/Alooma-iOS)
[![License](https://img.shields.io/cocoapods/l/Alooma-iOS.svg?style=flat)](http://cocoapods.org/pods/Alooma-iOS)
[![Platform](https://img.shields.io/cocoapods/p/Alooma-iOS.svg?style=flat)](http://cocoapods.org/pods/Alooma-iOS)

## Installation

Integrating the Alooma-iOS library can be done in a few simple steps, using [CocoaPods](http://cocoapods.org).

### To install CocoaPods:

1. Open a terminal and run `sudo gem install cocoapods`
2. Run `pod setup`

### To integrate the Alooma-iOS library in your project:

1. Create a file called `Podfile` in the root directory of your project
2. Add the following line to your Podfile:

```ruby
pod "Alooma-iOS"
```

3. Close XCode
4. Open a terminal and run `pod install` in the root directory of your project.
5. Open the new XCode workspace (`<your-project>.xcworkspace`)

### Compatibility

The Alooma-iOS library is a modified version of the [Mixpanel-iphone](http://www.github.com/mixpanel/mixpanel-iphone/) library, trimmed down to the bare event tracking necessities.

To integrate Alooma-iOS, you need to be using XCode 5 and a Base SDK of iOS 7.0. The library will work with deployment targets of iOS 6.0 and above.

## Initialization

To use the Alooma-iOS library, you must first initialize it with the hostname of your Alooma endpoint, and your token. Since this should be done only once, it makes sense to initialize Alooma-iOS when your app finishes launching:

```objectivec
#import <Alooma-iOS/Alooma.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    /* ... */
    
    [Alooma sharedInstanceWithToken:@"<your Alooma API token>" serverURL:@"<your Alooma endpoint>"];
    
    return YES;
}
```

Once initialized, you can use the Alooma-iOS library anywhere in your code just by calling the `sharedInstance` method:

```objectivec
    Alooma *alooma = [Alooma sharedInstance];
```

## Sending events

To send an event to Alooma, you can stick to the Mixpanel convention of `track:properties:`, or you can use the more free-form `trackCustomEvent:` to send a JSON serializable NSDictionary object.

### The Mixpanel Way

As we mentioned, Alooma-iOS is forked from Mixpanel, therefore it supports all of the methods implemented by the Mixpanel library:

- `track:`
- `track:properties:`
- `timeEvent:`
- `registerSuperProperties:` & `registerSuperPropertiesOnce:`
- `identify:`
- `flush` & `reset`

Basic event tracking can be implemented with the following code:

```objectivec
Alooma *alooma = [Alooma sharedInstance];

// Track an event just with a type
[alooma track:@"Event-type1"];

// Track an event with a type & properties
[alooma track:@"Event-type2" properties:@{
    @"prop1": @"abc",
    @"prop2": 123
}];
```

Using these methods will send events in the following format:

```js
{
    "event": "Event-type2",
    "properties": {
        "prop1": "abc",
        "prop2": 123,
        /* 
           additional properties added by the library:
           distinct_id, $os, time, sending_time, $model
           $manufacturer, $wifi, $screen_width, 
           $screen_height, ...
        */
    }
}
```

Documentation of the rest of the Mixpanel provided functions can be found on the [Mixpanel website](https://mixpanel.com/help/reference/ios).

### The Custom Way

In case you haven't been using Mixpanel, and all you want to do is send custom JSON objects, you can use the following snippet:

```objectivec
Alooma *alooma = [Alooma sharedInstance];

[alooma trackCustomEvent:@{
    @"custom-field1": @"event-type",
    @"custom-field2": @"abc",
    @"custom-field3": 123
}];
```

Using this method will send events in the following format:

```js
{
    "custom-field1": "event-type",
    "custom-field2": "abc",
    "custom-field3": 123,
    "properties": {
        /* 
           additional properties added by the library:
           distinct_id, $os, time, sending_time, $model
           $manufacturer, $wifi, $screen_width, 
           $screen_height, ...
        */
    }
}
```

### General Notes

- Alooma-iOS adds additional properties to each event:
  - time - the epoch time (seconds) when the event was tracked
  - sending_time - the epoch time (seconds) when the event was actually sent (in case the device was offline)
  - distinct_id - a unique identifier, identifying the device
  - additional fields and their values can be seen in the function [collectAutomaticProperties](https://github.com/Aloomaio/iossdk/blob/master/Alooma-iOS/Alooma.m#L781)

- The Alooma-iOS stores events in an internal queue of events, to be sent when the device is online. The queue has a fixed size of 500 events. If the device is offline and the queue fills up, the 501th event will cause the 1st (oldest) event to be popped from the queue and discarded.


## Testing with our SampleApp

To run the example project, clone the repo, and run `pod install` from the Example directory.

## Author

Alooma, info@alooma.com

## License

Alooma-iOS is available under the Apache v2 license. See the LICENSE file for more info.
