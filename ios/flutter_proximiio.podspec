#
# CocoaPods spec for apps that build plugins through CocoaPods (Flutter's default).
# Apps using Flutter's Swift Package Manager support use flutter_proximiio/Package.swift.
#
# The Proximi.io SDK pod is not on CocoaPods trunk. Add it to the app's ios/Podfile,
# inside the Runner target, at the same version as below:
#
#   pod 'Proximiio', :podspec => 'https://raw.githubusercontent.com/proximiio/proximiio-sdk-ios-binary/6.0.0-beta.66/Proximiio.podspec'
#
Pod::Spec.new do |s|
  s.name             = 'flutter_proximiio'
  s.version          = '6.0.0-beta.2'
  s.summary          = 'Proximi.io indoor positioning for Flutter (bridge over the Proximi.io iOS SDK v6).'
  s.description      = <<-DESC
Flutter plugin bridging the Proximi.io iOS SDK v6: positioning, floors, geofences,
privacy zones, venue data and wayfinding.
                       DESC
  s.homepage         = 'https://github.com/proximiio/flutter-proximiio'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Proximi.io' => 'support@proximi.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_proximiio/Sources/flutter_proximiio/**/*.swift'
  s.resource_bundles = { 'flutter_proximiio_privacy' => ['flutter_proximiio/Sources/flutter_proximiio/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.dependency 'Proximiio', '6.0.0-beta.66'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
