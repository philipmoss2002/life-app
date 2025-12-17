import 'dart:io';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../services/cloud_sync_service.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

class ErrorTraceScreen extends StatefulWidget {
  const ErrorTraceScreen({super.key});

  @override
  State<ErrorTraceScreen> createState() => _ErrorTraceScreenState();
}

class _ErrorTraceScreenState extends State<ErrorTraceScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Trace'),
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
                onPressed: _isRunning ? null : _traceNoSuchKeyError,
                child: _isRunning
                    ? const Text('Tracing Error...')
                    : const Text('Trace NoSuchKey Error'),
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
                final isError = log.contains('❌') ||
                    log.contains('ERROR') ||
                    log.contains('NoSuchKey');
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
    debugPrint('ERROR_TRACE: $message');
  }

  Future<void> _traceNoSuchKeyError() async {
    setState(() => _isRunning = true);
    _log('🔍 Starting comprehensive error trace...');

    try {
      // Step 1: Create test file
      await _step1CreateTestFile();

      // Step 2: Create document in database
      await _step2CreateDocument();

      // Step 3: Try sync step by step
      await _step3TrySync();
    } catch (e) {
      _log('❌ Error trace failed: $e');
      _log('📍 Stack trace: ${e.toString()}');
    }

    setState(() => _isRunning = false);
  }

  Future<File> _step1CreateTestFile() async {
    _log('📁 Step 1: Creating test file...');

    final tempDir = await getTemporaryDirectory();
    final testFilePath = '${tempDir.path}/error_trace_test.txt';
    final testFile = File(testFilePath);

    await testFile
        .writeAsString('Error trace test file\nCreated: ${DateTime.now()}');
    _log('✅ Test file created: $testFilePath');

    return testFile;
  }

  Future<Document> _step2CreateDocument() async {
    _log('📄 Step 2: Creating document in database...');

    final authService = AuthenticationService();
    final user = await authService.getCurrentUser();

    if (user == null) {
      throw Exception('User not authenticated');
    }

    final tempDir = await getTemporaryDirectory();
    final testFilePath = '${tempDir.path}/error_trace_test.txt';

    final testDoc = Document(
      userId: user.id,
      title: 'Error Trace Test ${DateTime.now().millisecondsSinceEpoch}',
      category: 'Other',
      filePaths: [testFilePath],
      createdAt: amplify_core.TemporalDateTime.now(),
      lastModified: amplify_core.TemporalDateTime.now(),
      version: 1,
      syncState: SyncState.notSynced.toJson(),
    );

    final docId = await DatabaseService.instance.createDocument(testDoc);
    _log('✅ Document created in database with ID: $docId');

    final docWithId = Document(
      id: docId.toString(),
      userId: testDoc.userId,
      title: testDoc.title,
      category: testDoc.category,
      filePaths: testDoc.filePaths,
      createdAt: testDoc.createdAt,
      lastModified: testDoc.lastModified,
      version: testDoc.version,
      syncState: testDoc.syncState,
      renewalDate: testDoc.renewalDate,
      notes: testDoc.notes,
    );

    return docWithId;
  }

  Future<void> _step3TrySync() async {
    _log('🔄 Step 3: Attempting sync with detailed tracing...');

    try {
      // Get the document we just created
      final docs = await DatabaseService.instance.getAllDocuments();
      final testDoc =
          docs.where((doc) => doc.title.contains('Error Trace Test')).last;

      _log('📄 Found test document: ${testDoc.title}');
      _log('📎 File paths: ${testDoc.filePaths}');

      // Try to queue for sync
      _log('🔄 Attempting to queue document for sync...');

      final syncService = CloudSyncService();

      // Enable bypass to avoid subscription issues
      CloudSyncService.enableSubscriptionBypass();
      _log('⚠️ Subscription bypass enabled');

      try {
        await syncService.queueDocumentSync(testDoc, SyncOperationType.upload);
        _log('✅ Document queued successfully');

        // Try immediate sync
        _log('🔄 Triggering immediate sync...');
        await syncService.syncNow();
        _log('✅ Sync completed without errors');
      } catch (e) {
        _log('❌ SYNC ERROR CAUGHT: $e');
        _log('📍 Error type: ${e.runtimeType}');

        if (e.toString().contains('NoSuchKey')) {
          _log('🎯 FOUND THE NoSuchKey ERROR!');
          _log('📍 Full error: ${e.toString()}');

          // Try to extract more details
          if (e is Exception) {
            _log('📍 Exception details: ${e.toString()}');
          }
        }

        rethrow;
      } finally {
        CloudSyncService.disableSubscriptionBypass();
        _log('✅ Subscription bypass disabled');
      }
    } catch (e) {
      _log('❌ Step 3 failed: $e');
      _log('📍 This is where the NoSuchKey error occurs');

      // Try to get more specific error information
      _analyzeError(e);
    }
  }

  void _analyzeError(dynamic error) {
    _log('🔬 Analyzing error in detail...');

    final errorString = error.toString();
    _log('📍 Error string: $errorString');

    if (errorString.contains('StorageNotFoundException')) {
      _log('🎯 Confirmed: StorageNotFoundException');
    }

    if (errorString.contains('NoSuchKey')) {
      _log('🎯 Confirmed: NoSuchKey error');

      // Try to extract the path that's causing issues
      final lines = errorString.split('\n');
      for (final line in lines) {
        if (line.contains('path') ||
            line.contains('key') ||
            line.contains('Path')) {
          _log('📍 Potential problematic path: $line');
        }
      }
    }

    if (errorString.contains('public/')) {
      _log('🎯 Error involves public/ path');
    }

    if (errorString.contains('documents/')) {
      _log('🎯 Error involves documents/ path');
    }

    _log('🔬 Error analysis complete');
  }
}
