import 'dart:io';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';

class UploadDownloadTestScreen extends StatefulWidget {
  const UploadDownloadTestScreen({super.key});

  @override
  State<UploadDownloadTestScreen> createState() =>
      _UploadDownloadTestScreenState();
}

class _UploadDownloadTestScreenState extends State<UploadDownloadTestScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;
  String? _uploadedPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload/Download Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _testUploadDownloadCycle,
                    child: _isRunning
                        ? const Text('Testing...')
                        : const Text('Test Upload → Download Cycle'),
                  ),
                ),
                if (_uploadedPath != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRunning
                          ? null
                          : () => _testDownloadOnly(_uploadedPath!),
                      child: const Text('Test Download Only'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isError = log.contains('❌') || log.contains('ERROR');
                final isSuccess = log.contains('✅') || log.contains('SUCCESS');

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red[50]
                        : isSuccess
                            ? Colors.green[50]
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isError
                          ? Colors.red[200]!
                          : isSuccess
                              ? Colors.green[200]!
                              : Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isError
                          ? Colors.red[800]
                          : isSuccess
                              ? Colors.green[800]
                              : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _log(String message) {
    final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    debugPrint('UPLOAD_DOWNLOAD_TEST: $message');
  }

  Future<void> _testUploadDownloadCycle() async {
    setState(() => _isRunning = true);
    _log('🚀 Starting upload → download cycle test...');

    try {
      // Create a test file
      final tempDir = await getTemporaryDirectory();
      final testFilePath = '${tempDir.path}/cycle_test.txt';
      final testFile = File(testFilePath);

      final testContent =
          'Upload/Download test file\nCreated at: ${DateTime.now()}\nContent: ${DateTime.now().millisecondsSinceEpoch}';
      await testFile.writeAsString(testContent);
      _log('✅ Created test file: $testFilePath');
      _log('📄 File content: ${testContent.split('\n').first}...');

      // Generate S3 key like the sync manager does
      // Get current user for proper isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      final documentId = 'test-doc-${DateTime.now().millisecondsSinceEpoch}';
      final fileName = 'cycle_test.txt';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final s3Key = 'documents/$userId/$documentId/$timestamp-$fileName';
      final publicPath = 'public/$s3Key';

      _log('📍 User ID: $userId');
      _log('📍 Generated S3 key: $s3Key');
      _log('📍 Full upload path: $publicPath');

      // Upload the file with user isolation in path
      _log('📤 Uploading file with user isolation...');
      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(testFile.path),
        path: StoragePath.fromString(publicPath),
      ).result;

      _log('✅ Upload successful!');
      _log('📍 Uploaded to: ${uploadResult.uploadedItem.path}');

      // Store the uploaded path for later testing
      _uploadedPath = uploadResult.uploadedItem.path;

      // Wait a moment for S3 consistency
      await Future.delayed(const Duration(seconds: 2));

      // Try to download using the same path
      await _testDownloadOnly(uploadResult.uploadedItem.path);

      // Clean up original test file
      await testFile.delete();
      _log('🧹 Cleaned up original test file');
    } catch (e) {
      _log('❌ Upload/Download cycle failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testDownloadOnly(String uploadedPath) async {
    _log('📥 Testing download from: $uploadedPath');

    try {
      final tempDir = await getTemporaryDirectory();
      final downloadPath =
          '${tempDir.path}/downloaded_${DateTime.now().millisecondsSinceEpoch}.txt';

      _log('📍 Download destination: $downloadPath');

      final downloadResult = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(uploadedPath),
        localFile: AWSFile.fromPath(downloadPath),
      ).result;

      _log('✅ Download successful!');
      _log('📍 Downloaded to: ${downloadResult.downloadedItem.path}');

      // Verify file content
      final downloadedFile = File(downloadPath);
      if (await downloadedFile.exists()) {
        final content = await downloadedFile.readAsString();
        _log('📄 Downloaded content: ${content.split('\n').first}...');

        // Clean up downloaded file
        await downloadedFile.delete();
        _log('🧹 Cleaned up downloaded file');
      } else {
        _log('❌ Downloaded file does not exist at expected path');
      }
    } catch (e) {
      _log('❌ Download failed: $e');
      _log('🔍 This indicates a path mismatch between upload and download');
    }
  }
}
