#
# Be sure to run `pod lib lint Alooma-iOS.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Alooma-iOS"
  s.version          = "0.1.3"
  s.summary          = "An iOS library for sending events to Alooma"
  s.homepage         = "https://github.com/aloomaio/iossdk.git"
  s.license          = 'Apache License, Version 2.0'
  s.author           = { "Alooma Inc" => "info@alooma.com" }
  s.source           = { :git => "https://github.com/aloomaio/iossdk.git", :tag => "v#{s.version}" }
  s.social_media_url = 'https://twitter.com/aloomainc'

  s.platform     = :ios, '6.0'
  s.requires_arc = true

  s.source_files = 'Alooma-iOS/*.{m,h}'

  s.library = 'icucore'
  s.frameworks = 'UIKit', 'Foundation', 'SystemConfiguration'
end
