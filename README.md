# Native File Picker

A Flutter plugin for picking files with native implementation supporting all Android versions and
iOS. This plugin provides a simple API for file selection with comprehensive file type filtering and
metadata extraction.

## Features

✅ **Cross-platform support** - Works on both Android and iOS  
✅ **All Android versions** - Supports Android API 19+ (Android 4.4+)  
✅ **iOS 11+** - Full iOS support with modern document picker  
✅ **Multiple file selection** - Pick single or multiple files  
✅ **File type filtering** - Filter by images, videos, audio, documents, or custom extensions  
✅ **File metadata** - Get file name, size, extension, and path  
✅ **Directory picker** - Select directories (where supported)  
✅ **Temporary file management** - Automatic cleanup of temporary files  
✅ **Scoped storage support** - Full Android 10+ scoped storage compatibility

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  native_file_picker: ^1.0.0
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml

<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" /><uses-permission
android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
```

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml

<key>NSDocumentsFolderUsageDescription</key><string>This app needs access to documents to pick
files
</string><key>NSDownloadsFolderUsageDescription</key><string>This app needs access to downloads to
pick files
</string>
```

## Usage

### Import the package

```dart
import 'package:native_file_picker/native_file_picker.dart';
```

### Pick a single file

```dart

final result = await
NativeFilePicker.pickFile
(
type: FileType.any,
);

if (result != null) {
final file = result.single;
print('Selected file: ${file.name}');
print('File path: ${file.path}');
print('File size: ${file.size} bytes');
}
```

### Pick multiple files

```dart

final result = await
NativeFilePicker.pickMultipleFiles
(
type: FileType.any,
);

if (result != null) {
for (final file in result.files) {
print('File: ${file.name}, Size: ${file.size}');
}
}
```

### Pick images only

```dart

final result = await
NativeFilePicker.pickMultipleFiles
(
type
:
FileType
.
image
,
);
```

### Pick custom file types

```dart

final result = await
NativeFilePicker.pickMultipleFiles
(
type: FileType.custom,
allowedExtensions: ['pdf', 'doc', 'docx', '
txt
'
]
,
);
```

### Pick directory (where supported)

```dart

final directoryPath = await
NativeFilePicker.getDirectoryPath
();if
(
directoryPath != null) {
print('Selected directory: $directoryPath');
}
```

### Clear temporary files

```dart

final cleared = await
NativeFilePicker.clearTemporaryFiles
();if
(
cleared) {
print('Temporary files cleared successfully');
}
```

## API Reference

### NativeFilePicker

#### Methods

- `pickFile({FileType type, List<String>? allowedExtensions})` → `Future<FilePickerResult?>`
    - Pick a single file

- `pickMultipleFiles({FileType type, List<String>? allowedExtensions})` → `Future<FilePickerResult?>`
    - Pick multiple files

- `getDirectoryPath()` → `Future<String?>`
    - Get directory path (platform dependent)

- `clearTemporaryFiles()` → `Future<bool>`
    - Clear temporary files created by the plugin

#### FileType enum

```dart
enum FileType {
  any, // Any file type
  media, // Images, videos, and audio
  image, // Images only
  video, // Videos only
  audio, // Audio files only
  custom, // Custom extensions (use allowedExtensions parameter)
}
```

### FilePickerResult

#### Properties

- `files` → `List<PlatformFile>` - List of selected files
- `single` → `PlatformFile?` - Get single file (convenience method)
- `paths` → `List<String>` - Get file paths
- `names` → `List<String>` - Get file names
- `isEmpty` → `bool` - Check if any files were picked
- `count` → `int` - Number of files picked

### PlatformFile

#### Properties

- `name` → `String` - File name including extension
- `path` → `String` - Full file path
- `size` → `int` - File size in bytes
- `bytes` → `List<int>?` - File bytes (nullable)
- `extension` → `String?` - File extension without dot
- `identifier` → `String?` - Platform specific identifier
- `file` → `File` - Get File object

## Error Handling

The plugin throws `FilePickerException` for various error conditions:

```dart
try {
final result = await NativeFilePicker.pickFile();
// Handle result
} on FilePickerException catch (e) {
print('File picker error: ${e.message}');
} catch (e) {
print('Unexpected error: $e');
}
```

## Platform Differences

### Android

- **API 19-28**: Uses legacy storage permissions
- **API 29+**: Uses scoped storage with full compatibility
- **File access**: Files are copied to app's cache directory for access
- **Multiple selection**: Supported on API 18+

### iOS

- **iOS 11+**: Uses modern UIDocumentPickerViewController
- **File access**: Files are copied to temporary directory
- **Security**: Handles security-scoped URLs automatically
- **Directory picker**: Limited support, returns URI strings

## Supported File Types

The plugin supports filtering by:

- **Images**: PNG, JPG, JPEG, GIF, BMP, WEBP, etc.
- **Videos**: MP4, AVI, MOV, MKV, etc.
- **Audio**: MP3, WAV, AAC, FLAC, etc.
- **Documents**: PDF, DOC, DOCX, TXT, etc.
- **Custom**: Any extensions you specify

## Permissions

### Android Permissions

```xml
<!-- Required for file access -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <!-- Required for Android 10 and below -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
android:maxSdkVersion="28" />

    <!-- Optional: For accessing all files on Android 11+ -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

### iOS Permissions

No special permissions required. The plugin uses the standard document picker which handles
permissions automatically.

## Performance Considerations

- Files are copied to temporary directories for security and access
- Large files may take time to copy
- Use `clearTemporaryFiles()` periodically to free up space
- Consider file size limits for your use case

## Troubleshooting

### Common Issues

1. **Android: "No activity result"**
    - Ensure your activity handles `onActivityResult`
    - Check if the file picker intent was properly launched

2. **iOS: "No view controller available"**
    - This usually happens if called too early in the app lifecycle
    - Ensure the UI is fully loaded before calling file picker methods

3. **File access denied**
    - Check that proper permissions are declared
    - On Android 11+, consider requesting `MANAGE_EXTERNAL_STORAGE` for full access

4. **Large file handling**
    - Monitor memory usage when handling large files
    - Consider streaming large files instead of loading into memory

### Debug Tips

- Enable debug logging to see file operations
- Check temporary directory usage
- Verify file paths are accessible
- Test on different Android versions and iOS devices

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Changelog

### 1.0.0

- Initial release
- Cross-platform file picker support
- Multiple file selection
- File type filtering
- Directory picker support
- Temporary file management