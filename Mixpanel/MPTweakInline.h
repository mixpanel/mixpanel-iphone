/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "MPTweakInlineInternal.h"

/**
  @abstract Common parameters in these macros.
  @param name_ The name of the tweak. Must be a constant NSString.
  @param default_ The default value of the tweak. If the user doesn't configure
    a custom value or the build is a release build, then the default value is used.
    The default value supports a variety of types, but all must be constant literals.
    Supported types include: BOOL, NSInteger, NSUInteger, CGFloat, NSString *, char *.
  @param min_ Optional, for numbers. The minimum value. Same restrictions as default.
  @param max_ Optional, for numbers. The maximum value. Same restrictions as default.
 */

/**
  @abstract Loads a tweak defined inline at startup.
  @warning If tweaks are disabled, this macro will return nil.
  @return A {@ref MPTweak} for the tweak that was registered at startup.
*/
#define MPTweakInline(name_, ...) _MPTweakInline(name_, __VA_ARGS__)

/**
  @abstract Loads the value of a tweak inline.
  @discussion To use a tweak, use this instead of the constant value you otherwise would.
    To use the same tweak in two places, define a C function that returns MPTweakValue.
  @return The current value of the tweak, or the default value if none is set.
 */
#define MPTweakValue(name_, ...) _MPTweakValue(name_, __VA_ARGS__)

/**
  @abstract Binds an object property to a tweak.
  @param object_ The object to bind to.
  @param property_ The property to bind.
  @discussion As long as the object is alive, the property will be updated to match the tweak.
 */
#define MPTweakBind(object_, property_, name_, ...) _MPTweakBind(object_, property_, name_, __VA_ARGS__)


