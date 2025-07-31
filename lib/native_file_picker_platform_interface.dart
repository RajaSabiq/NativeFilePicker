import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_file_picker_method_channel.dart';

abstract class NativeFilePickerPlatform extends PlatformInterface {
  /// Constructs a NativeFilePickerPlatform.
  NativeFilePickerPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeFilePickerPlatform _instance = MethodChannelNativeFilePicker();

  /// The default instance of [NativeFilePickerPlatform] to use.
  ///
  /// Defaults to [MethodChannelNativeFilePicker].
  static NativeFilePickerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeFilePickerPlatform] when
  /// they register themselves.
  static set instance(NativeFilePickerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
