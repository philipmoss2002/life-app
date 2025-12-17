import 'dart:io';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../services/cloud_sync_service.dart';
import '../services/subscription_service.dart' as sub;
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/sync_test_service.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

class DetailedSyncDebugScreen extends StatefulWidget {
  const DetailedSyncDebugScreen({super.key});

  @override
  State<DetailedSyncDebugScreen> createState() =>
      _DetailedSyncDebugScreenState();
}

class _DetailedSyncDebugScreenState extends State<DetailedSyncDebugScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Sync Debug'),
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
                    onPressed: _isRunning ? null : _runFullSyncTest,
                    child: _isRunning
                        ? const Text('Running Test...')
                        : const Text('Run Full Sync Test'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testSubscriptionOnly,
                        child: const Text('Test Subscription'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testSyncServiceOnly,
                        child: const Text('Test Sync Service'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testAmplifyAPI,
                        child: const Text('Test API Direct'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testBypassSubscription,
                        child: const Text('Bypass Subscription'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _testFileSyncOnly,
                    child: const Text('Test File Sync to S3'),
                  ),
                ),
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
    debugPrint('SYNC_DEBUG: $message');
  }

  Future<void> _runFullSyncTest() async {
    setState(() => _isRunning = true);
    _log('🚀 Starting comprehensive sync test...');

    try {
      // Test 1: Check Amplify
      await _testAmplify();

      // Test 2: Check Authentication
      await _testAuthentication();

      // Test 3: Check Subscription
      await _testSubscription();

      // Test 4: Check Sync Service
      await _testSyncService();

      // Test 5: Create and sync a test document
      await _testDocumentSync();

      _log('✅ Full sync test completed');
    } catch (e) {
      _log('❌ Full sync test failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testAmplify() async {
    _log('📡 Testing Amplify configuration...');

    try {
      final isConfigured = Amplify.isConfigured;
      _log('Amplify configured: $isConfigured');

      if (isConfigured) {
        // Test API plugin
        try {
          final api = Amplify.API;
          _log('✅ API plugin available: ${api.runtimeType}');
        } catch (e) {
          _log('❌ API plugin error: $e');
        }

        // Test Auth plugin
        try {
          final auth = Amplify.Auth;
          _log('✅ Auth plugin available: ${auth.runtimeType}');
        } catch (e) {
          _log('❌ Auth plugin error: $e');
        }

        // Test Storage plugin
        try {
          final storage = Amplify.Storage;
          _log('✅ Storage plugin available: ${storage.runtimeType}');
        } catch (e) {
          _log('❌ Storage plugin error: $e');
        }
      } else {
        _log('❌ Amplify not configured');
      }
    } catch (e) {
      _log('❌ Amplify test failed: $e');
    }
  }

  Future<void> _testAuthentication() async {
    _log('🔐 Testing authentication...');

    try {
      final authService = AuthenticationService();
      final isAuth = await authService.isAuthenticated();
      _log('User authenticated: $isAuth');

      if (isAuth) {
        final user = await authService.getCurrentUser();
        if (user != null) {
          _log('✅ Current user: ${user.email} (ID: ${user.id})');
        } else {
          _log('❌ User is null despite being authenticated');
        }
      } else {
        _log('❌ User not authenticated - sync will not work');
      }
    } catch (e) {
      _log('❌ Authentication test failed: $e');
    }
  }

  Future<void> _testSubscription() async {
    _log('💳 Testing subscription status...');

    try {
      final subscriptionService = sub.SubscriptionService();

      // Initialize if needed
      try {
        await subscriptionService.initialize();
        _log('Subscription service initialized');
      } catch (e) {
        _log('Subscription service already initialized or error: $e');
      }

      final status = await subscriptionService.getSubscriptionStatus();
      _log('Subscription status: ${status.name}');

      if (status == sub.SubscriptionStatus.active) {
        _log('✅ Active subscription found - sync should work');
      } else {
        _log('❌ No active subscription (${status.name}) - sync will not work');

        // Try force check
        _log('Attempting force check for purchases...');
        await subscriptionService.forceCheckPurchases();
        await Future.delayed(const Duration(seconds: 2));

        final newStatus = await subscriptionService.getSubscriptionStatus();
        _log('Status after force check: ${newStatus.name}');
      }
    } catch (e) {
      _log('❌ Subscription test failed: $e');
    }
  }

  Future<void> _testSubscriptionOnly() async {
    setState(() => _isRunning = true);
    await _testSubscription();
    setState(() => _isRunning = false);
  }

  Future<void> _testSyncService() async {
    _log('☁️ Testing cloud sync service...');

    try {
      final syncService = CloudSyncService();

      // Get sync status
      final status = await syncService.getSyncStatus();
      _log(
          'Sync status - Syncing: ${status.isSyncing}, Pending: ${status.pendingChanges}');

      // Try to initialize
      try {
        await syncService.initialize();
        _log('✅ Sync service initialized successfully');
      } catch (e) {
        _log('❌ Sync service initialization failed: $e');
        return;
      }

      // Try to start sync
      try {
        await syncService.startSync();
        _log('✅ Sync service started successfully');
      } catch (e) {
        _log('❌ Failed to start sync: $e');
      }
    } catch (e) {
      _log('❌ Sync service test failed: $e');
    }
  }

  Future<void> _testSyncServiceOnly() async {
    setState(() => _isRunning = true);
    await _testSyncService();
    setState(() => _isRunning = false);
  }

  Future<void> _testDocumentSync() async {
    _log('📄 Testing document sync...');

    try {
      // Get current user
      final authService = AuthenticationService();
      final user = await authService.getCurrentUser();

      if (user == null) {
        _log('❌ Cannot test document sync - no authenticated user');
        return;
      }

      // Create a test document
      final testDoc = Document(
        userId: user.id,
        title: 'Sync Test Document ${DateTime.now().millisecondsSinceEpoch}',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      _log('Creating test document: ${testDoc.title}');

      // Save to local database
      final docId = await DatabaseService.instance.createDocument(testDoc);
      _log('Document saved locally with ID: $docId');

      // Create document with ID for sync
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

      // Try to queue for sync
      try {
        final syncService = CloudSyncService();
        await syncService.queueDocumentSync(
            docWithId, SyncOperationType.upload);
        _log('✅ Document queued for sync successfully');

        // Try immediate sync
        await syncService.syncNow();
        _log('✅ Immediate sync triggered');

        // Wait and check sync state
        await Future.delayed(const Duration(seconds: 3));

        final updatedDocs = await DatabaseService.instance.getAllDocuments();
        final syncedDoc = updatedDocs.firstWhere(
          (doc) => doc.id == docId.toString(),
          orElse: () => testDoc,
        );

        final syncState = SyncState.fromJson(syncedDoc.syncState);
        _log('Document sync state after sync: ${syncState.name}');

        if (syncState == SyncState.synced) {
          _log('✅ Document successfully synced to cloud');
        } else {
          _log('❌ Document not synced - state: ${syncState.name}');
        }
      } catch (e) {
        _log('❌ Document sync failed: $e');
      }
    } catch (e) {
      _log('❌ Document sync test failed: $e');
    }
  }

  Future<void> _testAmplifyAPI() async {
    setState(() => _isRunning = true);
    _log('🔧 Testing Amplify API directly...');

    try {
      final testService = SyncTestService();

      // Test basic API connectivity
      final apiTest = await testService.testAmplifyAPI();
      if (apiTest) {
        _log('✅ Direct API test passed');
      } else {
        _log('❌ Direct API test failed');
      }

      // Test document query if we have a user
      final authService = AuthenticationService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        final queryTest = await testService.testDocumentQuery(user.id);
        if (queryTest) {
          _log('✅ Document query test passed');
        } else {
          _log('❌ Document query test failed');
        }
      }
    } catch (e) {
      _log('❌ API test failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testBypassSubscription() async {
    setState(() => _isRunning = true);
    _log('🚫 Testing sync bypass (ignoring subscription)...');

    try {
      final testService = SyncTestService();

      // Try to force initialize sync
      final initTest = await testService.forceInitializeSync();
      if (initTest) {
        _log('✅ Sync initialized without subscription check');

        // Try to create and upload a test document
        final authService = AuthenticationService();
        final user = await authService.getCurrentUser();

        if (user != null) {
          final testDoc = Document(
            id: 'test-${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
            title: 'Bypass Test Document',
            category: 'Other',
            filePaths: [],
            createdAt: amplify_core.TemporalDateTime.now(),
            lastModified: amplify_core.TemporalDateTime.now(),
            version: 1,
            syncState: SyncState.notSynced.toJson(),
          );

          final uploadTest = await testService.testDocumentUpload(testDoc);
          if (uploadTest) {
            _log('✅ Document upload bypassed subscription successfully');
          } else {
            _log('❌ Document upload failed even with bypass');
          }
        }
      } else {
        _log('❌ Sync initialization failed even with bypass');
      }
    } catch (e) {
      _log('❌ Bypass test failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testFileSyncOnly() async {
    setState(() => _isRunning = true);

    try {
      final authService = AuthenticationService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        await _testFileSync(user.id);
      } else {
        _log('❌ Cannot test file sync - no authenticated user');
      }
    } catch (e) {
      _log('❌ File sync test failed: $e');
    }

    setState(() => _isRunning = false);
  }

  Future<void> _testFileSync(String userId) async {
    _log('📎 Testing file sync to S3...');

    try {
      // Create a small test file
      final tempDir = await getTemporaryDirectory();
      final testFilePath = '${tempDir.path}/sync_test_file.txt';
      final testFile = File(testFilePath);

      await testFile.writeAsString(
          'This is a test file for sync verification.\nCreated at: ${DateTime.now()}');
      _log('Created test file: $testFilePath');

      // Create document with file
      final testDocWithFile = Document(
        userId: userId,
        title: 'File Sync Test ${DateTime.now().millisecondsSinceEpoch}',
        category: 'Other',
        filePaths: [testFilePath],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      _log('Creating document with file: ${testDocWithFile.title}');

      // Save to local database
      final docId =
          await DatabaseService.instance.createDocument(testDocWithFile);
      _log('Document with file saved locally with ID: $docId');

      // Create document with ID for sync
      final docWithFileAndId = Document(
        id: docId.toString(),
        userId: testDocWithFile.userId,
        title: testDocWithFile.title,
        category: testDocWithFile.category,
        filePaths: testDocWithFile.filePaths,
        createdAt: testDocWithFile.createdAt,
        lastModified: testDocWithFile.lastModified,
        version: testDocWithFile.version,
        syncState: testDocWithFile.syncState,
        renewalDate: testDocWithFile.renewalDate,
        notes: testDocWithFile.notes,
      );

      // Try to sync document with file
      try {
        final syncService = CloudSyncService();
        await syncService.queueDocumentSync(
            docWithFileAndId, SyncOperationType.upload);
        _log('✅ Document with file queued for sync');

        // Try immediate sync
        await syncService.syncNow();
        _log('✅ File sync triggered - this should upload to S3');

        // Wait longer for file upload
        await Future.delayed(const Duration(seconds: 5));

        final updatedDocs = await DatabaseService.instance.getAllDocuments();
        final syncedDoc = updatedDocs.firstWhere(
          (doc) => doc.id == docId.toString(),
          orElse: () => testDocWithFile,
        );

        final syncState = SyncState.fromJson(syncedDoc.syncState);
        _log('File document sync state: ${syncState.name}');

        if (syncState == SyncState.synced) {
          _log('✅ Document with file synced successfully');
          _log('✅ File should now be visible in S3 bucket');
        } else {
          _log('❌ File document not synced - state: ${syncState.name}');
        }
      } catch (e) {
        _log('❌ File sync failed: $e');
      }

      // Clean up test file
      try {
        await testFile.delete();
        _log('Cleaned up test file');
      } catch (e) {
        _log('Could not clean up test file: $e');
      }
    } catch (e) {
      _log('❌ File sync test failed: $e');
    }
  }
}
