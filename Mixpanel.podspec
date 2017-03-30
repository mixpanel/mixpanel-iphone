Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '3.1.3'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.libraries = 'icucore' 
  s.ios.deployment_target = '8.0'
  s.ios.source_files  = 'Mixpanel/**/*.{m,h}'
  s.ios.exclude_files = 'Mixpanel/MixpanelWatchProperties.{m,h}'
  s.ios.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
  s.ios.resources   = ['Mixpanel/**/*.{png,storyboard,xib}']
  s.ios.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore'
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files  = 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}'
  s.tvos.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h',  'Mixpanel/MPLogger.h'
  s.tvos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_TVOS'}
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.watchos.deployment_target = '2.0'
  s.watchos.source_files = 'Mixpanel/MixpanelWatchProperties.{m,h}', 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}'
  s.watchos.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
  s.watchos.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_WATCHOS'}
  s.watchos.frameworks = 'WatchKit', 'Foundation'
  s.osx.deployment_target = '10.10'
  s.osx.source_files  = 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}'
  s.osx.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h',  'Mixpanel/MPLogger.h'
  s.osx.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_MACOS'}
  s.osx.frameworks = 'Cocoa', 'Foundation', 'IOKit'

end
