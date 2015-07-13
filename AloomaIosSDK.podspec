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
  s.homepage         = "https://OrenMobixon@bitbucket.org/aloomasdkiosteam/alooma-ios-sdk.git"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Alooma" => "oren@mobixon.com" }
  s.source           = { :git => "https://OrenMobixon@bitbucket.org/aloomasdkiosteam/alooma-ios-sdk.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'AloomaIosSDK' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit'
  s.library = 'icucore'
  # s.dependency 'AFNetworking', '~> 2.3'
end
