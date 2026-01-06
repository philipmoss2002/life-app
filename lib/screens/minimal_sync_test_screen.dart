import 'dart:io';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';

class MinimalSyncTestScreen extends StatefulWidget {
  const MinimalSyncTestScreen({super.key});

  @override
  State<MinimalSyncTestScreen> createState() => _MinimalSyncTestScreenState();
}

class _MinimalSyncTestScreenState extends State<MinimalSyncTestScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal Sync Test'),
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _testMinimalSync,
                child: _isRunning
                    ? const Text('Testing...')
                    : const Text('Test Minimal File Upload'),
              ),
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
    debugPrint('MINIMAL_SYNC: $message');
  }

  Future<void> _testMinimalSync() async {
    setState(() => _isRunning = true);
    _log('🚀 Starting minimal sync test (bypassing all services)...');

    try {
      // Create test file
      final tempDir = await getTemporaryDirectory();
      final testFilePath = '${tempDir.path}/minimal_test.txt';
      final testFile = File(testFilePath);

      await testFile
          .writeAsString('Minimal sync test\nTimestamp: ${DateTime.now()}');
      _log('✅ Created test file: $testFilePath');

      // Generate S3 path with user isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;
      final documentId =
          'minimal-test-${DateTime.now().millisecondsSinceEpoch}';
      final fileName = 'minimal_test.txt';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final s3Key = 'documents/$userId/$documentId/$timestamp-$fileName';
      final publicPath = 'public/$s3Key';

      _log('📍 User ID: $userId');
      _log('📍 S3 Key: $s3Key');
      _log('📍 Public Path (with user isolation): $publicPath');

      // Upload directly to S3 with user isolation in path
      _log('📤 Uploading to S3 with user isolation...');
      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(testFile.path),
        path: StoragePath.fromString(publicPath),
      ).result;

      _log('✅ Upload successful: ${uploadResult.uploadedItem.path}');

      // Wait for S3 consistency
      await Future.delayed(const Duration(seconds: 2));

      // Try to download the same file (this is where verification fails)
      _log('📥 Attempting download for verification...');
      final downloadPath = '${tempDir.path}/downloaded_minimal.txt';

      try {
        final downloadResult = await Amplify.Storage.downloadFile(
          path: StoragePath.fromString(publicPath),
          localFile: AWSFile.fromPath(downloadPath),
        ).result;

        _log('✅ Download successful: ${downloadResult.downloadedItem.path}');

        // Verify content
        final downloadedFile = File(downloadPath);
        if (await downloadedFile.exists()) {
          final content = await downloadedFile.readAsString();
          _log('📄 Downloaded content verified: ${content.split('\n').first}');
          await downloadedFile.delete();
        }
      } catch (e) {
        _log('❌ Download failed (this is the NoSuchKey source): $e');
        _log('🎯 The file was uploaded but cannot be downloaded immediately');
        _log('📍 This suggests S3 consistency issues or path problems');
      }

      // Clean up
      await testFile.delete();
      _log('🧹 Cleaned up test file');

      _log('✅ Minimal sync test completed');
      _log(
          '💡 If download failed, this explains the NoSuchKey in verification');
    } catch (e) {
      _log('❌ Minimal sync test failed: $e');
    }

    setState(() => _isRunning = false);
  }
}
