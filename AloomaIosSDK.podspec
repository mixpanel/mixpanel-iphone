#
# Be sure to run `pod lib lint AloomaIosSDK.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "AloomaIosSDK"
  s.version          = "0.1.0"
  s.summary          = "An iOS SDK For tracking events on Alooma"
  s.description      = <<-DESC
                       An iOS SDK For tracking events on Alooma

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://www.github.com/aloomaio/iossdk.git"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'Apache 2'
  s.author           = { "Alooma" => "info@alooma.io" }
  s.source           = { :git => "https://www.github.com/aloomaio/iossdk.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Alooma/*'
  s.resource_bundles = {
    'AloomaIosSDK' => ['Alooma/*.png']
  }

  # s.public_header_files = 'Alooma/*.h'
  # s.frameworks = 'UIKit'
  s.library = 'icucore'
  # s.dependency 'AFNetworking', '~> 2.3'
end
