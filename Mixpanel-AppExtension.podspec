Pod::Spec.new do |s|
  s.name         = 'Mixpanel-AppExtension'
  s.version      = '3.1.3'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.ios.deployment_target = '8.0'
  s.source_files  = 'Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeople.{m,h}', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetwork.{m,h}', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h', 'Mixpanel/MPFoundation.h', 'Mixpanel/MixpanelExceptionHandler.{m,h}'
  s.private_header_files = 'Mixpanel/MixpanelPrivate.h', 'Mixpanel/MixpanelPeoplePrivate.h', 'Mixpanel/MPNetworkPrivate.h', 'Mixpanel/MPLogger.h'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_APP_EXTENSION'}
  s.frameworks = 'UIKit', 'Foundation'
  s.libraries = 'icucore'
end
