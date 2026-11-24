# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-11-24

### Fixed
- iOS: restore the `Int64` conversion for the streaming copy size. 1.0.3 failed
  to compile with `cannot convert value of type 'Int' to expected argument type
  'Int64'`.

## [1.0.3] - 2026-11-24

### Fixed
- iOS: present `UIDocumentPickerViewController` from the top-most view controller
  instead of the window root. Fixes pickers that silently failed in modal,
  SwiftUI, and add-to-app embeddings ("already presenting" /
  "whose view is not in the window hierarchy").

## [1.0.2] - 2026-09-23

### Fixed
- Android no longer copies the picked file synchronously on the main/UI thread.
  Large media (e.g. long videos) no longer freezes the app, shows a black screen,
  or triggers an ANR while the file is copied to temporary storage. The copy now
  runs on a background executor and the result is posted back to the main thread.
- Android in-flight picker requests are now resolved when the activity is
  detached/recreated, so the Dart future can never hang indefinitely.
- File `size` is returned as a 64-bit value instead of a truncated `Int`, which
  previously wrapped negative for files larger than 2 GB.
- iOS copies picked files with a streaming `InputStream`/`OutputStream` instead
  of loading the entire file into memory, avoiding memory spikes/memory kills for
  very large media.

### Added
- New `NativeFilePicker.onPickProgress` stream (0.0–1.0) reporting copy progress
  while a picked file is moved into temporary storage on both platforms.
- A configurable timeout on the picker method-channel calls so a stalled native
  call cannot leave the UI stuck.

## [1.0.1] - 2026-09-23

### Fixed
- iOS no longer prefixes picked files with a generated identifier when copying
  them to the temporary directory. Each picked file is now stored inside a unique
  temporary subdirectory using its original filename, so the returned `path`
  basename always matches the user's filename (e.g. `document.pdf`) during
  upload, update, and download.
- Implemented the missing `getPlatformVersion` method on iOS and Android so the
  template unit and integration tests pass.

## [1.0.0] - 2024-01-15

### Added
- Initial release of Native File Picker plugin
- Cross-platform support for Android (API 19+) and iOS (11+)
- Single and multiple file selection
- File type filtering (any, image, video, audio, media, custom)
- Custom file extension filtering
- Directory picker support
- File metadata extraction (name, size, extension, path)
- Temporary file management with cleanup functionality
- Comprehensive error handling with FilePickerException
- Full scoped storage support for Android 10+
- Security-scoped URL handling for iOS
- Complete example app demonstrating all features
- Extensive documentation and API reference

### Features
- **File Picking**: Pick single or multiple files with native platform dialogs
- **Type Filtering**: Filter files by type (images, videos, audio, documents, custom)
- **Metadata**: Access file name, size, extension, and path information
- **Directory Selection**: Pick directories where platform supports it
- **Temporary Management**: Automatic temporary file handling with manual cleanup
- **Cross-Platform**: Consistent API across Android and iOS platforms
- **Modern Android**: Full support for scoped storage and modern file access
- **iOS Integration**: Native UIDocumentPickerViewController integration

### Technical Details
- **Minimum Android**: API 19 (Android 4.4 KitKat)
- **Minimum iOS**: iOS 11.0
- **Flutter**: Compatible with Flutter 3.0+
- **Dart**: Compatible with Dart 3.0+
- **Kotlin**: Android implementation in Kotlin
- **Swift**: iOS implementation in Swift 5.0

### Performance
- Efficient file copying to temporary directories
- Memory-conscious handling of file metadata
- Optimized for both small and large file selections
- Background processing where appropriate

### Security
- Respects platform security models
- Proper handling of security-scoped URLs on iOS
- Scoped storage compliance on Android
- Temporary file isolation and cleanup