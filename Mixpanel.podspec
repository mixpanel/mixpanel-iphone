Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '3.0.4'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.default_subspec = 'Mixpanel'
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.source_files = 'Mixpanel/MixpanelWatchProperties.{m,h}', 'Mixpanel/MixpanelExceptionHandler.{m,h}', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MPLogger.h',  'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h'
  s.watchos.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
  s.watchos.frameworks = 'WatchKit', 'Foundation'
  s.watchos.deployment_target = '2.0'
  s.osx.deployment_target = ''

  s.subspec 'Mixpanel' do |ss|
    ss.source_files  = 'Mixpanel/**/*.{m,h}'
    ss.exclude_files = 'Mixpanel/MixpanelWatchProperties.{m,h}'
    ss.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
    ss.resources 	 = ['Mixpanel/**/*.{png,storyboard}']
    ss.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.ios.deployment_target = '8.0'
  end

  s.subspec 'tvOS' do |ss|
    ss.source_files  = 'Mixpanel/NSInvocation+MPHelpers.{m,h}', 'Mixpanel/UIColor+MPColor.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/UIImage+MPAverageColor.{m,h}', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MixpanelExceptionHandler.{m,h}', 'Mixpanel/UIImage+MPImageEffects.{m,h}', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MPLogger.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPFoundation.h'
    ss.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h',  'Mixpanel/MPLogger.h'
    ss.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.tvos.deployment_target = '9.0'
  end

  s.subspec 'AppExtension' do |ss|
    ss.source_files  = ['Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{h,m}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{h,m}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/Mixpanel+AutomaticEvents.h', 'Mixpanel/AutomaticEventsConstants.h']
    ss.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
    ss.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_APP_EXTENSION'}
    ss.frameworks = 'UIKit', 'Foundation', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.ios.deployment_target = '8.0'
  end
end
