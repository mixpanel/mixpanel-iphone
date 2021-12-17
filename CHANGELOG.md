#

## [v3.9.2](https://github.com/mixpanel/mixpanel-iphone/tree/v3.9.2) (2021-12-14)

**Closed issues:**

- Remove vulnerable NSCoding [\#908](https://github.com/mixpanel/mixpanel-iphone/issues/908)

**Merged pull requests:**

- Remove integrations code for braze and airship [\#962](https://github.com/mixpanel/mixpanel-iphone/pull/962)

From this version, Mixpanel SDK no longer sets property $braze_external_id and $ios_urban_airship_channel_id automatically. Please refer to this doc for the integration setup guide if you need to export Mixpanel Cohorts to Braze or Airship.

## [v4.0.0.beta.4](https://github.com/mixpanel/mixpanel-iphone/tree/v4.0.0.beta.4) (2021-12-13)

**Closed issues:**

- Crash in connectToABTestDesigner [\#959](https://github.com/mixpanel/mixpanel-iphone/issues/959)
- Crash in \[Mixpanel unarchiveFromFile:asClass:\] [\#958](https://github.com/mixpanel/mixpanel-iphone/issues/958)
- 3.9.x build failure on Mac Catalyst due to MPFree deprecation [\#957](https://github.com/mixpanel/mixpanel-iphone/issues/957)
- Feature: Ability to import tracked events older than five days [\#712](https://github.com/mixpanel/mixpanel-iphone/issues/712)

**Merged pull requests:**

- Add network queue for network request [\#961](https://github.com/mixpanel/mixpanel-iphone/pull/961)
- Add NSSecureCoding allowed classes to avoid warning [\#956](https://github.com/mixpanel/mixpanel-iphone/pull/956)

## [v4.0.0.beta.3](https://github.com/mixpanel/mixpanel-iphone/tree/v4.0.0.beta.3) (2021-11-15)

**Closed issues:**

- $carrier property can be reported as `nil` when there is multiple SIMs support [\#949](https://github.com/mixpanel/mixpanel-iphone/issues/949)

**Merged pull requests:**

- Replace NSKeyedArchiver with SQLite for offline tracking [\#953](https://github.com/mixpanel/mixpanel-iphone/pull/953)

#

## [v3.9.1](https://github.com/mixpanel/mixpanel-iphone/tree/v3.9.1) (2021-11-14)

**Closed issues:**

- APN settings [\#952](https://github.com/mixpanel/mixpanel-iphone/issues/952)

**Merged pull requests:**

- Carrier name retrieval [\#955](https://github.com/mixpanel/mixpanel-iphone/pull/955)
- Remove alias check when calling identify [\#954](https://github.com/mixpanel/mixpanel-iphone/pull/954)

## [4.0.0.beta.2](https://github.com/mixpanel/mixpanel-iphone/tree/4.0.0.beta.2) (2021-06-26)

**Closed issues:**

- Realme , iphone [\#946](https://github.com/mixpanel/mixpanel-iphone/issues/946)
- Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '+\[MPSwizzler [\#937](https://github.com/mixpanel/mixpanel-iphone/issues/937)
- iOS 13 crashes on `\[MixpanelExceptionHandler sharedHandler\]` [\#872](https://github.com/mixpanel/mixpanel-iphone/issues/872)

**Merged pull requests:**

- Improve README for quick start guide [\#947](https://github.com/mixpanel/mixpanel-iphone/pull/947)
- remove github actions for uploading Carthage artifact [\#945](https://github.com/mixpanel/mixpanel-iphone/pull/945)

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

## [v4.0.0.beta.1](https://github.com/mixpanel/mixpanel-iphone/tree/v4.0.0.beta.1) (2021-04-08)

**Closed issues:**

- Concurrency Issue with TimedEvents [\#926](https://github.com/mixpanel/mixpanel-iphone/issues/926)

**Merged pull requests:**

- delete M&E code [\#930](https://github.com/mixpanel/mixpanel-iphone/pull/930)







