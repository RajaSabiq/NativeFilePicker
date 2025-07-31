import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_file_picker_platform_interface.dart';

/// An implementation of [NativeFilePickerPlatform] that uses method channels.
class MethodChannelNativeFilePicker extends NativeFilePickerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_file_picker');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
