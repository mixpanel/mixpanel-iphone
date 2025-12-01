# Copilot Coding Agent Instructions for mixpanel-iphone

## Repository Overview

This repository contains the **Mixpanel iOS SDK** (Objective-C), an analytics library for tracking user interactions in iOS, tvOS, watchOS, and macOS applications. The SDK version is currently 5.0.8.

**Key characteristics:**
- Language: Objective-C (not Swift - a Swift SDK exists in a separate repo `mixpanel-swift`)
- Minimum iOS deployment target: 11.0 (tvOS 11.0, watchOS 4.0, macOS 10.13)
- License: Apache 2.0
- Package managers supported: CocoaPods, Carthage, Swift Package Manager

## Repository Structure

```
/
├── Sources/                       # Main SDK source code (~4900 lines of Obj-C)
│   ├── Mixpanel.h/.m              # Main public API (track events, identify users)
│   ├── MixpanelPeople.h/.m        # User profile/People API
│   ├── MixpanelGroup.h/.m         # Group analytics API
│   ├── MPNetwork.h/.m             # Network layer
│   ├── MPDB.h/.m                  # SQLite persistence layer
│   ├── MixpanelPersistence.h/.m   # Data persistence
│   └── Mixpanel/PrivacyInfo.xcprivacy  # Apple privacy manifest
├── HelloMixpanel/                 # Sample app and test project
│   ├── HelloMixpanel.xcodeproj/   # Xcode project for iOS/tvOS/watchOS/macOS demo apps
│   ├── HelloMixpanel/             # iOS sample app source
│   ├── HelloMixpanelTests/        # XCTest unit tests
│   ├── MixpanelMacDemo*/          # macOS demo app
│   └── MixpanelWatchDemo*/        # watchOS demo app
├── Package.swift                  # Swift Package Manager manifest
├── Mixpanel.podspec               # CocoaPods specification
├── scripts/                       # Build and release scripts
│   ├── carthage.sh                # Carthage build script
│   ├── generate_docs.sh           # API documentation generator
│   └── release.py                 # Release automation script
├── docs/                          # Generated API documentation (HTML)
└── .github/workflows/             # CI/CD workflows
    ├── mixpanel.yml               # Main CI: builds and tests on every PR/push
    └── release.yml                # Creates GitHub releases on tag push
```

## Building and Testing

**IMPORTANT:** This SDK requires macOS with Xcode to build and test. The CI runs on `macos-latest` GitHub runners.

### CI Workflow (mixpanel.yml)
The main CI workflow runs on every push and PR to master. The exact command sequence is:

```bash
# Navigate to HelloMixpanel directory (REQUIRED)
cd HelloMixpanel

# Build and run tests for iOS simulator
xcodebuild \
  -scheme "[iOS] HelloMixpanel" \
  -derivedDataPath Build/ \
  -destination "name=iPhone 15 Pro,OS=latest" \
  -configuration Debug \
  ONLY_ACTIVE_ARCH=NO \
  ENABLE_TESTABILITY=YES \
  -enableCodeCoverage YES \
  clean build test | xcpretty -c

# Then from repo root, run CocoaPods linting
pod lib lint --platforms=ios,tvos --allow-warnings
```

### Available Xcode Schemes
Located in `HelloMixpanel/HelloMixpanel.xcodeproj/xcshareddata/xcschemes/`:
- `[iOS] HelloMixpanel` - iOS app and tests (primary scheme for CI)
- `[tvOS] HelloMixpanel` - tvOS app and tests
- `MixpanelMacDemo` - macOS demo app

### Running Tests Locally
Tests are in `HelloMixpanel/HelloMixpanelTests/`. Test files include:
- `HelloMixpanelTests.m` - Main SDK functionality tests
- `MixpanelPeopleTests.m` - People API tests
- `MixpanelGroupTests.m` - Group analytics tests
- `MixpanelOptOutTests.m` - GDPR/privacy opt-out tests
- `MixpanelTypeTests.m` - Type handling tests
- `MPNetworkTests.m` - Network layer tests
- `AutomaticEventsTests.m` - Automatic event tracking tests

The test base class is `MixpanelBaseTests.m/.h` which provides helper methods.

## Key Files for Common Changes

### SDK Version
The version is defined in two places that must stay in sync:
- `Mixpanel.podspec` line: `s.version = '5.0.8'`
- `Sources/Mixpanel.m` line: `#define VERSION @"5.0.8"`

The `scripts/release.py` script handles version bumps.

### Public API Headers
- `Sources/Mixpanel.h` - Main public API
- `Sources/MixpanelPeople.h` - People API
- `Sources/MixpanelGroup.h` - Group API
- `Sources/MixpanelType.h` - Type protocols

### Platform-Specific Code
Platform macros control conditional compilation:
- `TARGET_OS_WATCH` - watchOS specific code
- `TARGET_OS_OSX` - macOS specific code
- `TARGET_OS_TV` - tvOS specific code
- `MIXPANEL_NO_AUTOMATIC_EVENTS_SUPPORT` - Platforms without auto-events

## CocoaPods and Carthage

### Validating CocoaPods Changes
After modifying `Mixpanel.podspec`:
```bash
pod lib lint --platforms=ios,tvos --allow-warnings
```

### Building with Carthage
```bash
./scripts/carthage.sh
```
This sets `XCODE_XCCONFIG_FILE` for architecture exclusions and builds xcframeworks.

## Documentation

API docs are in `docs/` and generated with `appledoc`:
```bash
./scripts/generate_docs.sh
```

## Important Notes

1. **ARC Required**: The library requires Automatic Reference Counting (`#if !__has_feature(objc_arc) #error`)

2. **Debug vs Release**: In DEBUG builds, `flushInterval` defaults to 2 seconds; in Release it's 60 seconds.

3. **Test Database Cleanup**: Tests create SQLite files named `{token}_MPDB.sqlite`. The `removeDBfile:` helper cleans these up.

4. **Skipped Tests**: Some tests are skipped in the scheme (`MixpanelBaseTests`, `MPNotificationTests`, `MixpanelGroupTests/testRemoveGroupBasic`).

5. **Test Server**: Tests use `https://34a272abf23d.com` as a fake server URL for network failure testing.

## Trust These Instructions

These instructions are validated against the repository structure and CI configuration. Only perform additional searches if:
- Information appears incomplete or outdated
- Encountered an error not covered here
- Working on features outside the documented scope
