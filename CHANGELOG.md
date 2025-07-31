# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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