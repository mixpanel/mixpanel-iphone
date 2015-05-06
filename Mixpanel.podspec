Pod::Spec.new do |s|
  s.name         = 'Mixpanel'
  s.version      = '2.7.4'
  s.summary      = 'iPhone tracking library for Mixpanel Analytics'
  s.homepage     = 'https://mixpanel.com'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.platform     = :ios, '6.0'
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-iphone.git', :tag => "v#{s.version}" }
  s.source_files  = 'Mixpanel/**/*.{m,h}'
  s.resources 	 = ['Mixpanel/**/*.{png,storyboard}']
  s.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'Accelerate', 'CoreGraphics', 'QuartzCore'
  s.libraries = 'icucore', 'MPCategoryHelpers'
  s.requires_arc = true

  s.subspec 'MPCategoryHelpers' do |ss|
    ss.preserve_paths = 'Mixpanel/MPCategoryHelpers.h'
    ss.vendored_libraries = 'Mixpanel/libMPCategoryHelpers.a'
    ss.libraries = 'MPCategoryHelpers'
  end
end
