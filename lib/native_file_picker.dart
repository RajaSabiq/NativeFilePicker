library native_file_picker;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'native_file_picker_platform_interface.dart';

/// The main class for native file picker
class NativeFilePicker {
  static const MethodChannel _channel = MethodChannel('native_file_picker');
  static const EventChannel _progressChannel =
      EventChannel('native_file_picker/progress');

  static StreamController<double>? _progressController;
  static StreamSubscription<dynamic>? _progressSubscription;

  /// Stream of file-copy progress ranging from 0.0 to 1.0.
  ///
  /// Events are emitted while a picked file is being copied into temporary
  /// storage on the native side. Listen to this *before* calling [pickFile]
  /// or [pickMultipleFiles] so a progress indicator can be shown during the
  /// copy phase. When the source size is unknown the stream jumps straight
  /// to 1.0 on completion.
  static Stream<double> get onPickProgress {
    final controller = _progressController ??=
        StreamController<double>.broadcast(
      onListen: () {
        _progressSubscription = _progressChannel
            .receiveBroadcastStream()
            .listen((event) {
          if (event is num && _progressController != null) {
            _progressController!.add(event.toDouble().clamp(0.0, 1.0).toDouble());
          }
        });
      },
      onCancel: () {
        _progressSubscription?.cancel();
        _progressSubscription = null;
      },
    );
    return controller.stream;
  }

  Future<String?> getPlatformVersion() {
    return NativeFilePickerPlatform.instance.getPlatformVersion();
  }

  /// Pick a single file
  static Future<FilePickerResult?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'allowMultiple': false,
        'type': type.name,
        'allowedExtensions': allowedExtensions,
      };

      final result = await _channel
          .invokeMethod('pickFiles', arguments)
          .timeout(
            timeout,
            onTimeout: () {
              throw const FilePickerException('File picker timed out');
            },
          );

      if (result != null && result is Map) {
        return FilePickerResult.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PlatformException catch (e) {
      throw FilePickerException(e.message ?? 'Unknown error occurred');
    }
  }

  /// Pick multiple files
  static Future<FilePickerResult?> pickMultipleFiles({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'allowMultiple': true,
        'type': type.name,
        'allowedExtensions': allowedExtensions,
      };

      final result = await _channel
          .invokeMethod('pickFiles', arguments)
          .timeout(
            timeout,
            onTimeout: () {
              throw const FilePickerException('File picker timed out');
            },
          );

      if (result != null && result is Map) {
        return FilePickerResult.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PlatformException catch (e) {
      throw FilePickerException(e.message ?? 'Unknown error occurred');
    }
  }

  /// Get directory path
  static Future<String?> getDirectoryPath({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final result = await _channel
          .invokeMethod('getDirectoryPath')
          .timeout(
            timeout,
            onTimeout: () {
              throw const FilePickerException('Directory picker timed out');
            },
          );
      return result as String?;
    } on PlatformException catch (e) {
      throw FilePickerException(e.message ?? 'Unknown error occurred');
    }
  }

  /// Clear temporary files (iOS specific)
  static Future<bool> clearTemporaryFiles() async {
    try {
      final result = await _channel.invokeMethod('clearTemporaryFiles');
      return result as bool;
    } on PlatformException catch (e) {
      throw FilePickerException(e.message ?? 'Unknown error occurred');
    }
  }
}

/// File types supported by the picker
enum FileType {
  any,
  media,
  image,
  video,
  audio,
  custom,
}

/// Represents a picked file
class PlatformFile {
  const PlatformFile({
    required this.name,
    required this.path,
    required this.size,
    this.bytes,
    this.extension,
    this.identifier,
  });

  /// File name including extension
  final String name;

  /// Full file path
  final String path;

  /// File size in bytes
  final int size;

  /// File bytes (nullable)
  final List<int>? bytes;

  /// File extension without dot
  final String? extension;

  /// Platform specific identifier
  final String? identifier;

  /// Get File object
  File get file => File(path);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'bytes': bytes,
      'extension': extension,
      'identifier': identifier,
    };
  }

  factory PlatformFile.fromMap(Map<String, dynamic> map) {
    return PlatformFile(
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      size: map['size'] ?? 0,
      bytes: map['bytes']?.cast<int>(),
      extension: map['extension'],
      identifier: map['identifier'],
    );
  }

  @override
  String toString() {
    return 'PlatformFile(name: $name, path: $path, size: $size, extension: $extension)';
  }
}

/// Result of file picking operation
class FilePickerResult {
  const FilePickerResult({
    required this.files,
  });

  /// List of picked files
  final List<PlatformFile> files;

  /// Get single file (convenience method)
  PlatformFile? get single => files.isNotEmpty ? files.first : null;

  /// Get file paths
  List<String> get paths => files.map((f) => f.path).toList();

  /// Get file names
  List<String> get names => files.map((f) => f.name).toList();

  /// Check if any files were picked
  bool get isEmpty => files.isEmpty;

  /// Number of files picked
  int get count => files.length;

  Map<String, dynamic> toMap() {
    return {
      'files': files.map((f) => f.toMap()).toList(),
    };
  }

  factory FilePickerResult.fromMap(Map<String, dynamic> map) {
    final filesList = map['files'] as List? ?? [];
    return FilePickerResult(
      files: filesList
          .map((f) => PlatformFile.fromMap(Map<String, dynamic>.from(f)))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'FilePickerResult(files: ${files.length} files)';
  }
}

/// Exception thrown by file picker operations
class FilePickerException implements Exception {
  const FilePickerException(this.message);

  final String message;

  @override
  String toString() => 'FilePickerException: $message';
}