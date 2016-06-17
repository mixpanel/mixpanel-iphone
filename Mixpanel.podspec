Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '2.9.9'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.requires_arc = true
  s.default_subspec = 'Mixpanel'
  s.platforms = { :ios => '7.0', :watchos => '2.0', :tvos => '9.0' }

  s.subspec 'Mixpanel' do |ss|
    ss.source_files  = 'Mixpanel/**/*.{m,h}', 'Mixpanel/**/*.swift'
    ss.exclude_files = 'Mixpanel/MixpanelWatchOS.{m,h}', 'Mixpanel/Mixpanel+HostWatchOS.{m,h}'
    ss.resources 	 = ['Mixpanel/**/*.{png,storyboard}']
    ss.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.platform = { :ios, :tvos }
  end

  s.subspec 'MixpanelHostWatchOS' do |ss|
    ss.source_files  = 'Mixpanel/**/*.{m,h}', 'Mixpanel/**/*.swift'
    ss.exclude_files = 'Mixpanel/MixpanelWatchOS.{m,h}'
    ss.resources   = ['Mixpanel/**/*.{png,storyboard}']
    ss.frameworks = 'WatchConnectivity', 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.platform = :ios
  end

  s.subspec 'WatchOS' do |ss|
    ss.source_files = ['Mixpanel/MixpanelWatchOS.{m,h}', 'Mixpanel/MPLogger.h']
    ss.frameworks = 'WatchConnectivity', 'Foundation'
    ss.platform = :watchos
  end

  s.subspec 'AppExtension' do |ss|
    ss.source_files  = ['Mixpanel/Mixpanel.{m,h}', 'Mixpanel/MPLogger.h', 'Mixpanel/NSData+MPBase64.{m,h}', 'Mixpanel/MPFoundation.h', 'Mixpanel/Mixpanel+AutomaticEvents.h', 'Mixpanel/AutomaticEventsConstants.h']
    ss.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MIXPANEL_APP_EXTENSION'}
    ss.frameworks = 'UIKit', 'Foundation', 'Accelerate', 'CoreGraphics', 'QuartzCore'
    ss.libraries = 'icucore'
    ss.platform = :ios
  end
end
