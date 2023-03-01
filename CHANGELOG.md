#

## [v5.0.2](https://github.com/mixpanel/mixpanel-iphone/tree/v5.0.2) (2023-03-01)

### Enhancements

- identity v3 changes [\#1009](https://github.com/mixpanel/mixpanel-iphone/pull/1009)
- Delete .travis.yml [\#1006](https://github.com/mixpanel/mixpanel-iphone/pull/1006)

### Fixes

- Disable watchOS in CI [\#1010](https://github.com/mixpanel/mixpanel-iphone/pull/1010)

#

## [v5.0.1](https://github.com/mixpanel/mixpanel-iphone/tree/v5.0.1) (2022-11-09)

### Fixes

- build xcframeworks with carthage, import targetconditionals, delete app extension scheme [\#1004](https://github.com/mixpanel/mixpanel-iphone/pull/1004)

#

## [v5.0.0](https://github.com/mixpanel/mixpanel-iphone/tree/v5.0.0) (2022-08-16)

### Enhancements

- Remove Decide and make trackAutomaticEvents required parameter [\#996](https://github.com/mixpanel/mixpanel-iphone/pull/996)

#

## [v4.2.0](https://github.com/mixpanel/mixpanel-iphone/tree/v4.2.0) (2022-06-24)

### Enhancements

- use millisecond precision for event.time property [\#994](https://github.com/mixpanel/mixpanel-iphone/pull/994)

#

## [v4.1.6](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.6) (2022-05-20)

#

## [v4.1.5](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.5) (2022-05-05)

### Enhancements

- track "implementation" and each debug launch [\#988](https://github.com/mixpanel/mixpanel-iphone/pull/988)

#

## [v4.1.4](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.4) (2022-04-26)

### Enhancements

- add dev nps survey [\#986](https://github.com/mixpanel/mixpanel-iphone/pull/986)
- Remove `nocilla` and `ocmock` [\#979](https://github.com/mixpanel/mixpanel-iphone/pull/979)

### Fixes

- only add $distinct\_id to people records [\#987](https://github.com/mixpanel/mixpanel-iphone/pull/987)

#

## [v4.1.3](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.3) (2022-02-15)

### Fixes

- fix SPM fails to build a macOS target [\#984](https://github.com/mixpanel/mixpanel-iphone/pull/984)
- Fix the events being improperly removed when automatic events being off [\#983](https://github.com/mixpanel/mixpanel-iphone/pull/983)

#

## [v4.1.2](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.2) (2022-02-03)

### Enhancements

- Remove `nocilla` and `ocmock` [\#979](https://github.com/mixpanel/mixpanel-iphone/pull/979)

### Fixes

- Fix duplicated header in the CocoaPods build [\#982](https://github.com/mixpanel/mixpanel-iphone/pull/982)
- fix missing import MixpanelGroup [\#981](https://github.com/mixpanel/mixpanel-iphone/pull/981)
- Fix first app open not respecting Automatic Events setting from server [\#980](https://github.com/mixpanel/mixpanel-iphone/pull/980)

#

## [v4.1.1](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.1) (2022-01-22)

### Fixes:
- Set content-type to `application/json` as required by Mixpanel ingestion API [\#977](https://github.com/mixpanel/mixpanel-iphone/pull/977)

  This will avoid events being rejected by the server if there is any string containing "& % \".

#

## [v4.1.0](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.0) (2022-01-14)
### Caution: In this version, we have a bug that event names with & or % will be rejected by the server. We recommend you update to 3.1.1 or above.

### Enhancements

- add useUniqueDistinctId [\#972](https://github.com/mixpanel/mixpanel-iphone/pull/972)

### Fixes

- fix incorrect app version property [\#974](https://github.com/mixpanel/mixpanel-iphone/pull/974)
- add \[NSSet class\] to unarchiveFromFile [\#973](https://github.com/mixpanel/mixpanel-iphone/pull/973)

**Closed issues:**

- User Id not attached to events after createAlias call [\#824](https://github.com/mixpanel/mixpanel-iphone/issues/824)

#

## [v4.0.0](https://github.com/mixpanel/mixpanel-iphone/tree/v4.1.0) (2022-01-14)

## Caution: From v4.0.0.beta.3 to v4.1.0, we have a bug that events with ampersand(&) will be rejected by the server. We recommend you update to v4.1.1 or above.
-  Remove Messages & Experiments feature, for more detail, please check this [post](https://mixpanel.com/blog/why-were-sunsetting-messaging-and-experiments/#:~:text=A%20year%20from%20now%2C%20on,offering%20discounts%20for%20getting%20started):

- Upgrade the offline tracking storage with SQLite, it will:
  - Reduce crashes caused by race conditions for serializing data
  - Greatly improve the performance for intensive tracking needs
  - Fix the memory leaks
  - Be a non-functional change and transparent to all users, the new version will take care of migrating data from the NSKeyedArchiver files to SQLite DBs, no data will be lost.
#

## [v3.9.2](https://github.com/mixpanel/mixpanel-iphone/tree/v3.9.2) (2021-12-14)

**Closed issues:**

- Remove vulnerable NSCoding [\#908](https://github.com/mixpanel/mixpanel-iphone/issues/908)

#

## [v3.9.2](https://github.com/mixpanel/mixpanel-iphone/tree/v3.9.2) (2021-12-14)

**Closed issues:**

- Remove vulnerable NSCoding [\#908](https://github.com/mixpanel/mixpanel-iphone/issues/908)

**Merged pull requests:**

- Remove integrations code for braze and airship [\#962](https://github.com/mixpanel/mixpanel-iphone/pull/962)

From this version, Mixpanel SDK no longer sets property $braze_external_id and $ios_urban_airship_channel_id automatically. Please refer to this doc for the integration setup guide if you need to export Mixpanel Cohorts to Braze or Airship.

#

## [v3.9.1](https://github.com/mixpanel/mixpanel-iphone/tree/v3.9.1) (2021-11-14)

**Closed issues:**

- APN settings [\#952](https://github.com/mixpanel/mixpanel-iphone/issues/952)

**Merged pull requests:**

- Carrier name retrieval [\#955](https://github.com/mixpanel/mixpanel-iphone/pull/955)
- Remove alias check when calling identify [\#954](https://github.com/mixpanel/mixpanel-iphone/pull/954)
#

## [v3.8.0](https://github.com/mixpanel/mixpanel-iphone/tree/v3.8.0) (2021-06-15)

**Closed issues:**

- Integration with UrbanAirship crashes on App startup with version 14 of UrbanAirship SDK [\#938](https://github.com/mixpanel/mixpanel-iphone/issues/938)
- +\[MPSwizzler swizzleSelector:onClass:withBlock:named:async:\] unrecognized selector sent to class  [\#934](https://github.com/mixpanel/mixpanel-iphone/issues/934)

**Merged pull requests:**

- enable Github Actions to automatically upload Carthage artifact [\#941](https://github.com/mixpanel/mixpanel-iphone/pull/941)
- migrate to Airship 14.0 for the Urban Airship integration  [\#939](https://github.com/mixpanel/mixpanel-iphone/pull/939)
- Add a CHANGELOG placeholder [\#936](https://github.com/mixpanel/mixpanel-iphone/pull/936)
- Add github workflow for auto release [\#935](https://github.com/mixpanel/mixpanel-iphone/pull/935)
- Migrate CI to github actions [\#933](https://github.com/mixpanel/mixpanel-iphone/pull/933)
- update readme for beta version [\#931](https://github.com/mixpanel/mixpanel-iphone/pull/931)
































