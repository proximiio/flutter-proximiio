Pod::Spec.new do |s|
  s.name             = 'flutter_proximiio'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for Proximiio indoor positioning'
  s.description      = <<-DESC
Flutter plugin for Proximiio indoor positioning with support for beacons, geofencing, and floor detection.
                       DESC
  s.homepage         = 'https://github.com/proximiio/flutter-proximiio'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Proximiio' => 'info@proximi.fi' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Proximiio', '5.3.0'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.static_framework = true
end
