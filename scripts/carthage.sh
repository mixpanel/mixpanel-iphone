export XCODE_XCCONFIG_FILE=$PWD/scripts/carthage.xcconfig
carthage build --platform ios,tvos,macos,watchos --use-xcframeworks --no-skip-current