Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '5.0.2'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.libraries = 'icucore'
  s.swift_version = '4.2'
  s.ios.deployment_target = '10.0'
  all_files = 'Sources/**/*.{m,h}'
  public_header_files = 'Sources/Mixpanel.h', 'Sources/MixpanelType.h', 'Sources/MixpanelGroup.h', 'Sources/MixpanelType.h', 'Sources/MixpanelPeople.h'
  private_header_files = 'Sources/MixpanelPeoplePrivate.h', 'Sources/MixpanelGroupPrivate.h', 'Sources/MPNetworkPrivate.h', 'Sources/MixpanelPrivate.h', 'Sources/SessionMetadata.h', 'Sources/MixpanelIdentity.h', 'Sources/MPJSONHander.h', 'Sources/MixpanelPersistence.h', 'Sources/MPDB.h'
  s.ios.source_files  = all_files
  s.ios.exclude_files = 'Sources/MixpanelWatchProperties.{m,h}','Sources/Include/*.h'
  s.ios.public_header_files = public_header_files
  s.ios.private_header_files = private_header_files
  s.ios.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore', 'StoreKit'
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files  = all_files
  s.tvos.exclude_files = 'Sources/MixpanelWatchProperties.{m,h}','Sources/Include/*.h'
  s.tvos.public_header_files = public_header_files
  s.tvos.private_header_files = private_header_files
  s.tvos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_TVOS'}
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.watchos.deployment_target = '3.0'
  s.watchos.source_files = all_files
  s.watchos.exclude_files = 'Sources/AutomaticEvents.{m,h}','Sources/Include/*.h'
  s.watchos.public_header_files = public_header_files
  s.watchos.private_header_files = private_header_files
  s.watchos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_WATCHOS'}
  s.watchos.frameworks = 'WatchKit', 'Foundation'
  s.osx.deployment_target = '10.10'
  s.osx.source_files  = all_files
  s.osx.exclude_files = 'Sources/MixpanelWatchProperties.{m,h}'
  s.osx.exclude_files = 'Sources/AutomaticEvents.{m,h}','Sources/Include/*.h'
  s.osx.public_header_files = public_header_files
  s.osx.private_header_files = private_header_files
  s.osx.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_MACOS'}
  s.osx.frameworks = 'Cocoa', 'Foundation', 'IOKit'

end
