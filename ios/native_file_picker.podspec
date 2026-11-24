Pod::Spec.new do |s|
  s.name             = 'native_file_picker'
  s.version          = '1.0.3'
  s.summary          = 'A Flutter plugin for picking files with native implementation.'
  s.description      = <<-DESC
A Flutter plugin that provides native file picking functionality for both Android and iOS platforms.
Supports all Android versions and iOS with comprehensive file type filtering and multiple file selection.
                       DESC
  s.homepage         = 'https://github.com/RajaSabiq/NativeFilePicker'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'RajaSabiq' => 'https://github.com/RajaSabiq' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end