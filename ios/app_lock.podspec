#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_lock.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_lock'
  s.version          = '0.1.0'
  s.summary          = 'App switcher privacy cover for the app_lock Flutter package.'
  s.description      = <<-DESC
Covers the window with a blur while the app is inactive, so the app switcher never shows its content.
                       DESC
  s.homepage         = 'https://github.com/Umar888/app_lock'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'umar-ghaffar' => 'https://github.com/Umar888' }
  s.source           = { :path => '.' }
  s.source_files = 'app_lock/Sources/app_lock/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'app_lock_privacy' => ['app_lock/Sources/app_lock/PrivacyInfo.xcprivacy']}
end
