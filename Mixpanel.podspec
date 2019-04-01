Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '3.4.5'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.libraries = 'icucore'
  s.swift_version = '4.2'
  s.ios.deployment_target = '8.0'
  s.ios.source_files  = 'Mixpanel/**/*.{m,h}'
  s.ios.exclude_files = 'Mixpanel/MixpanelWatchProperties.{m,h}'
  s.ios.public_header_files = 'Mixpanel/Mixpanel.h', 'Mixpanel/MixpanelType.h', 'Mixpanel/MixpanelGroup.h', 'Mixpanel/MixpanelType.h', 'Mixpanel/MixpanelPeople.h', 'Mixpanel/MPTweak.h', 'Mixpanel/MPTweakInline.h', 'Mixpanel/MPTweakInlineInternal.h', 'Mixpanel/MPTweakStore.h', 'Mixpanel/_MPTweakBindObserver.h'
  s.ios.private_header_files = 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/SessionMetadata.h'
  s.ios.resources   = ['Mixpanel/**/*.{png,storyboard,xib}']
  s.ios.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore', 'StoreKit', 'UserNotifications'
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files  = 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelGroup.{m,h}', 'Mixpanel/MixpanelType.{m,h}', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}', 'Mixpanel/SessionMetadata.{m,h}'
  s.tvos.public_header_files = 'Mixpanel/Mixpanel.h', 'Mixpanel/MixpanelPeople.h', 'Mixpanel/MixpanelGroup.h', 'Mixpanel/MixpanelType.h'
  s.tvos.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/SessionMetadata.h', 'Mixapnel/MixpanelGroupPrivate.h'
  s.tvos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_TVOS'}
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.watchos.deployment_target = '3.0'
  s.watchos.source_files = 'Mixpanel/MixpanelWatchProperties.{m,h}', 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelGroup.{m,h}', 'Mixpanel/MixpanelType.{m,h}', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}', 'Mixpanel/SessionMetadata.{m,h}'
  s.watchos.public_header_files = 'Mixpanel/Mixpanel.h', 'Mixpanel/MixpanelPeople.h', 'Mixpanel/MixpanelGroup.h', 'Mixpanel/MixpanelType.h'
  s.watchos.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/SessionMetadata.h'
  s.watchos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_WATCHOS'}
  s.watchos.frameworks = 'WatchKit', 'Foundation'
  s.osx.deployment_target = '10.10'
  s.osx.source_files  = 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MixpanelGroup.{m,h}', 'Mixpanel/MixpanelType.{m,h}', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}', 'Mixpanel/SessionMetadata.{m,h}'
  s.osx.public_header_files = 'Mixpanel/Mixpanel.h', 'Mixpanel/MixpanelPeople.h', 'Mixpanel/MixpanelGroup.h', 'Mixpanel/MixpanelType.h'
  s.osx.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelGroupPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/SessionMetadata.h'
  s.osx.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_MACOS'}
  s.osx.frameworks = 'Cocoa', 'Foundation', 'IOKit'

end
