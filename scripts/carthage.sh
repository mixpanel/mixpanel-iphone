export XCODE_XCCONFIG_FILE=$PWD/scripts/carthage.xcconfig
carthage build --no-skip-current
carthage archive Mixpanel
