import 'package:flutter_test/flutter_test.dart';
import 'package:native_file_picker/native_file_picker.dart';
import 'package:native_file_picker/native_file_picker_platform_interface.dart';
import 'package:native_file_picker/native_file_picker_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeFilePickerPlatform
    with MockPlatformInterfaceMixin
    implements NativeFilePickerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NativeFilePickerPlatform initialPlatform =
      NativeFilePickerPlatform.instance;

  test('$MethodChannelNativeFilePicker is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeFilePicker>());
  });

  test('getPlatformVersion', () async {
    NativeFilePicker nativeFilePickerPlugin = NativeFilePicker();
    MockNativeFilePickerPlatform fakePlatform = MockNativeFilePickerPlatform();
    NativeFilePickerPlatform.instance = fakePlatform;

    expect(await nativeFilePickerPlugin.getPlatformVersion(), '42');
  });
}
