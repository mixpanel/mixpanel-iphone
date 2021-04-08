Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '4.0.0.rc'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.libraries = 'icucore'
  s.swift_version = '4.2'
  s.ios.deployment_target = '10.0'
  s.ios.source_files  = 'Sources/**/*.{m,h}'
  s.ios.exclude_files = 'Sources/MixpanelWatchProperties.{m,h}'
  s.ios.public_header_files = 'Sources/Mixpanel.h', 'Sources/MixpanelType.h', 'Sources/MixpanelGroup.h', 'Sources/MixpanelType.h', 'Sources/MixpanelPeople.h'
  s.ios.private_header_files = 'Sources/MixpanelPeoplePrivate.h', 'Sources/MixpanelGroupPrivate.h', 'Sources/MPNetworkPrivate.h', 'Sources/MixpanelPrivate.h', 'Sources/SessionMetadata.h'
  s.ios.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore', 'StoreKit'
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files  = 'Sources/Mixpanel.{m,h}', 'Sources/MixpanelPrivate.h', 'Sources/MixpanelPeople.{m,h}', 'Sources/MixpanelGroup.{m,h}', 'Sources/MixpanelType.{m,h}', 'Sources/MixpanelGroupPrivate.h', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MPNetwork.{m,h}', 'Sources/MPNetworkPrivate.h', 'Sources/MPLogger.h', 'Sources/MPFoundation.h', 'Sources/MixpanelExceptionHandler.{m,h}', 'Sources/SessionMetadata.{m,h}'
  s.tvos.public_header_files = 'Sources/Mixpanel.h', 'Sources/MixpanelPeople.h', 'Sources/MixpanelGroup.h', 'Sources/MixpanelType.h'
  s.tvos.private_header_files = 'Sources/MixpanelPrivate.h', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MPNetworkPrivate.h', 'Sources/SessionMetadata.h', 'Sources/MixpanelGroupPrivate.h'
  s.tvos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_TVOS'}
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.watchos.deployment_target = '3.0'
  s.watchos.source_files = 'Sources/MixpanelWatchProperties.{m,h}', 'Sources/Mixpanel.{m,h}', 'Sources/MixpanelPrivate.h', 'Sources/MixpanelPeople.{m,h}', 'Sources/MixpanelGroup.{m,h}', 'Sources/MixpanelType.{m,h}', 'Sources/MixpanelGroupPrivate.h', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MPNetwork.{m,h}', 'Sources/MPNetworkPrivate.h', 'Sources/MPLogger.h', 'Sources/MPFoundation.h', 'Sources/MixpanelExceptionHandler.{m,h}', 'Sources/SessionMetadata.{m,h}'
  s.watchos.public_header_files = 'Sources/Mixpanel.h', 'Sources/MixpanelPeople.h', 'Sources/MixpanelGroup.h', 'Sources/MixpanelType.h'
  s.watchos.private_header_files = 'Sources/MixpanelPrivate.h', 'Sources/MixpanelGroupPrivate.h', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MPNetworkPrivate.h', 'Sources/SessionMetadata.h'
  s.watchos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_WATCHOS'}
  s.watchos.frameworks = 'WatchKit', 'Foundation'
  s.osx.deployment_target = '10.10'
  s.osx.source_files  = 'Sources/Mixpanel.{m,h}', 'Sources/MixpanelPrivate.h', 'Sources/MixpanelPeople.{m,h}', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MixpanelGroup.{m,h}', 'Sources/MixpanelType.{m,h}', 'Sources/MixpanelGroupPrivate.h', 'Sources/MPNetwork.{m,h}', 'Sources/MPNetworkPrivate.h', 'Sources/MPLogger.h', 'Sources/MPFoundation.h', 'Sources/MixpanelExceptionHandler.{m,h}', 'Sources/SessionMetadata.{m,h}'
  s.osx.public_header_files = 'Sources/Mixpanel.h', 'Sources/MixpanelPeople.h', 'Sources/MixpanelGroup.h', 'Sources/MixpanelType.h'
  s.osx.private_header_files = 'Sources/MixpanelPrivate.h', 'Sources/MixpanelGroupPrivate.h', 'Sources/MixpanelPeoplePrivate.h', 'Sources/MPNetworkPrivate.h', 'Sources/SessionMetadata.h'
  s.osx.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_MACOS'}
  s.osx.frameworks = 'Cocoa', 'Foundation', 'IOKit'

end
