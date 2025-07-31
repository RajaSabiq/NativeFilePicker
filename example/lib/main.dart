import 'package:flutter/material.dart';
import 'package:native_file_picker/native_file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native File Picker Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Native File Picker Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<PlatformFile> _selectedFiles = [];
  String? _directoryPath;
  bool _isLoading = false;

  Future<void> _pickSingleFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await NativeFilePicker.pickFile(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = [result.files.first];
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMultipleFiles() async {
    setState(() => _isLoading = true);

    try {
      final result = await NativeFilePicker.pickMultipleFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      _showError('Error picking files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    setState(() => _isLoading = true);

    try {
      final result = await NativeFilePicker.pickMultipleFiles(
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      _showError('Error picking images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCustomFiles() async {
    setState(() => _isLoading = true);

    try {
      final result = await NativeFilePicker.pickMultipleFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      _showError('Error picking custom files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDirectory() async {
    setState(() => _isLoading = true);

    try {
      final path = await NativeFilePicker.getDirectoryPath();

      if (path != null) {
        setState(() {
          _directoryPath = path;
        });
      }
    } catch (e) {
      _showError('Error picking directory: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearTempFiles() async {
    try {
      final cleared = await NativeFilePicker.clearTemporaryFiles();
      if (cleared) {
        _showSuccess('Temporary files cleared successfully');
      }
    } catch (e) {
      _showError('Error clearing temp files: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.grey,
              ),
            const SizedBox(height: 16),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickSingleFile,
                  icon: const Icon(Icons.file_present),
                  label: const Text('Pick Single File'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickMultipleFiles,
                  icon: const Icon(Icons.file_copy),
                  label: const Text('Pick Multiple Files'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Images'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickCustomFiles,
                  icon: const Icon(Icons.description),
                  label: const Text('Pick Documents'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickDirectory,
                  icon: const Icon(Icons.folder),
                  label: const Text('Pick Directory'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearTempFiles,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Temp'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Directory info
            if (_directoryPath != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Directory:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_directoryPath!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Files list
            if (_selectedFiles.isNotEmpty) ...[
              Text(
                'Selected Files (${_selectedFiles.length}):',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            file.extension?.toUpperCase() ?? 'FILE',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        title: Text(
                          file.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Size: ${_formatFileSize(file.size)}'),
                            Text(
                              'Path: ${file.path}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(file.name),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Name: ${file.name}'),
                                    Text('Size: ${_formatFileSize(file.size)}'),
                                    Text(
                                        'Extension: ${file.extension ?? 'None'}'),
                                    Text('Path: ${file.path}'),
                                    if (file.identifier != null)
                                      Text('ID: ${file.identifier}'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No files selected',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap any button above to pick files',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
