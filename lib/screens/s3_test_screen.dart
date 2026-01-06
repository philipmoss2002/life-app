import 'dart:io';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';

class S3TestScreen extends StatefulWidget {
  const S3TestScreen({super.key});

  @override
  State<S3TestScreen> createState() => _S3TestScreenState();
}

class _S3TestScreenState extends State<S3TestScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3 Direct Test'),
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
                onPressed: _isRunning ? null : _testS3Upload,
                child: _isRunning
                    ? const Text('Testing S3...')
                    : const Text('Test S3 Upload Direct'),
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
    debugPrint('S3_TEST: $message');
  }

  Future<void> _testS3Upload() async {
    setState(() => _isRunning = true);
    _log('🚀 Starting direct S3 upload test...');

    try {
      // Check Amplify configuration
      if (!Amplify.isConfigured) {
        _log('❌ Amplify not configured');
        return;
      }
      _log('✅ Amplify is configured');

      // Create a test file
      final tempDir = await getTemporaryDirectory();
      final testFilePath = '${tempDir.path}/s3_direct_test.txt';
      final testFile = File(testFilePath);

      await testFile
          .writeAsString('Direct S3 test file\nCreated at: ${DateTime.now()}');
      _log('✅ Created test file: $testFilePath');

      // Test 1: Try public upload
      await _testPublicUpload(testFile);

      // Test 2: Try private upload
      await _testPrivateUpload(testFile);

      // Test 3: Try guest upload
      await _testGuestUpload(testFile);

      // Clean up
      await testFile.delete();
      _log('✅ Cleaned up test file');
    } catch (e) {
      _log('❌ S3 test failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testPublicUpload(File testFile) async {
    _log(
        '📤 Testing public upload (deprecated - use private for user isolation)...');

    try {
      final s3Key = 'test/public_${DateTime.now().millisecondsSinceEpoch}.txt';

      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(testFile.path),
        path: StoragePath.fromString('public/$s3Key'),
      ).result;

      _log('✅ Public upload successful: ${uploadResult.uploadedItem.path}');
      _log('⚠️ WARNING: Public uploads are not user-isolated!');
    } catch (e) {
      _log('❌ Public upload failed: $e');
    }
  }

  Future<void> _testPrivateUpload(File testFile) async {
    _log('📤 Testing private upload...');

    try {
      final s3Key = 'test/private_${DateTime.now().millisecondsSinceEpoch}.txt';

      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(testFile.path),
        path: StoragePath.fromString('private/$s3Key'),
      ).result;

      _log('✅ Private upload successful: ${uploadResult.uploadedItem.path}');
    } catch (e) {
      _log('❌ Private upload failed: $e');
    }
  }

  Future<void> _testGuestUpload(File testFile) async {
    _log('📤 Testing guest upload...');

    try {
      final s3Key = 'test/guest_${DateTime.now().millisecondsSinceEpoch}.txt';

      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(testFile.path),
        path: StoragePath.fromString(s3Key),
      ).result;

      _log('✅ Guest upload successful: ${uploadResult.uploadedItem.path}');
    } catch (e) {
      _log('❌ Guest upload failed: $e');
    }
  }
}
