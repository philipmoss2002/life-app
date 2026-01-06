import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_sync_service.dart';
import '../services/subscription_service.dart' as sub;
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../models/sync_state.dart';

class SyncDiagnosticScreen extends StatefulWidget {
  const SyncDiagnosticScreen({super.key});

  @override
  State<SyncDiagnosticScreen> createState() => _SyncDiagnosticScreenState();
}

class _SyncDiagnosticScreenState extends State<SyncDiagnosticScreen> {
  final List<DiagnosticResult> _results = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Diagnostics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runDiagnostics,
                child: _isRunning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Running Diagnostics...'),
                        ],
                      )
                    : const Text('Run Sync Diagnostics'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      result.passed ? Icons.check_circle : Icons.error,
                      color: result.passed ? Colors.green : Colors.red,
                    ),
                    title: Text(result.testName),
                    subtitle: Text(result.message),
                    trailing: result.action != null
                        ? TextButton(
                            onPressed: result.action,
                            child: const Text('Fix'),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // Run all diagnostic tests
    await _checkNetworkConnectivity();
    await _checkAmplifyConfiguration();
    await _checkAuthentication();
    await _checkSubscriptionStatus();
    await _checkCloudSyncService();
    await _checkSyncSettings();
    await _checkDocumentSyncStates();
    await _checkSyncQueue();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      final isConnected = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      _addResult(DiagnosticResult(
        testName: 'Network Connectivity',
        passed: isConnected,
        message: isConnected
            ? 'Connected via ${result.map((r) => r.name).join(', ')}'
            : 'No network connection detected',
      ));
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Network Connectivity',
        passed: false,
        message: 'Error checking connectivity: $e',
      ));
    }
  }

  Future<void> _checkAmplifyConfiguration() async {
    try {
      final isConfigured = Amplify.isConfigured;

      _addResult(DiagnosticResult(
        testName: 'Amplify Configuration',
        passed: isConfigured,
        message: isConfigured
            ? 'Amplify is properly configured'
            : 'Amplify is not configured',
      ));

      // Check for API plugin specifically
      if (isConfigured) {
        try {
          // Try to access the API plugin to verify it's added
          Amplify.API;
          _addResult(DiagnosticResult(
            testName: 'API Plugin',
            passed: true,
            message: 'API plugin is available',
          ));
        } catch (e) {
          _addResult(DiagnosticResult(
            testName: 'API Plugin',
            passed: false,
            message: 'API plugin not found: $e',
            action: () => _showApiPluginFix(),
          ));
        }
      }
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Amplify Configuration',
        passed: false,
        message: 'Error checking Amplify: $e',
      ));
    }
  }

  Future<void> _checkAuthentication() async {
    try {
      final authService = AuthenticationService();
      final isAuthenticated = await authService.isAuthenticated();
      final user = await authService.getCurrentUser();

      _addResult(DiagnosticResult(
        testName: 'User Authentication',
        passed: isAuthenticated && user != null,
        message: isAuthenticated && user != null
            ? 'Authenticated as ${user.email}'
            : 'User not authenticated',
      ));
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'User Authentication',
        passed: false,
        message: 'Error checking authentication: $e',
      ));
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscriptionService = sub.SubscriptionService();

      // Try to initialize
      try {
        await subscriptionService.initialize();
      } catch (e) {
        debugPrint('Subscription service already initialized: $e');
      }

      final status = await subscriptionService.getSubscriptionStatus();
      final isActive = status == sub.SubscriptionStatus.active;

      _addResult(DiagnosticResult(
        testName: 'Subscription Status',
        passed: isActive,
        message: 'Status: ${status.name}',
        action: !isActive ? () => _forceCheckSubscription() : null,
      ));
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Subscription Status',
        passed: false,
        message: 'Error checking subscription: $e',
      ));
    }
  }

  Future<void> _checkCloudSyncService() async {
    try {
      final syncService = CloudSyncService();
      final syncStatus = await syncService.getSyncStatus();

      _addResult(DiagnosticResult(
        testName: 'Cloud Sync Service',
        passed: true,
        message:
            'Syncing: ${syncStatus.isSyncing}, Pending: ${syncStatus.pendingChanges}',
      ));

      // Try to initialize sync
      try {
        await syncService.initialize();
        _addResult(DiagnosticResult(
          testName: 'Sync Initialization',
          passed: true,
          message: 'Cloud sync service initialized successfully',
        ));
      } catch (e) {
        _addResult(DiagnosticResult(
          testName: 'Sync Initialization',
          passed: false,
          message: 'Failed to initialize sync: $e',
        ));
      }
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Cloud Sync Service',
        passed: false,
        message: 'Error accessing sync service: $e',
      ));
    }
  }

  Future<void> _checkSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncPaused = prefs.getBool('sync_paused') ?? false;
      final wifiOnly = prefs.getBool('sync_wifi_only') ?? false;

      _addResult(DiagnosticResult(
        testName: 'Sync Settings',
        passed: !syncPaused,
        message: syncPaused
            ? 'Sync is paused by user'
            : 'Sync enabled${wifiOnly ? ' (Wi-Fi only)' : ''}',
        action: syncPaused ? () => _resumeSync() : null,
      ));
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Sync Settings',
        passed: false,
        message: 'Error checking sync settings: $e',
      ));
    }
  }

  Future<void> _checkDocumentSyncStates() async {
    try {
      final dbService = DatabaseService.instance;
      final documents = await dbService.getAllDocuments();

      final syncStates = <SyncState, int>{};
      for (final doc in documents) {
        final state = SyncState.fromJson(doc.syncState);
        syncStates[state] = (syncStates[state] ?? 0) + 1;
      }

      final unsyncedCount = (syncStates[SyncState.notSynced] ?? 0) +
          (syncStates[SyncState.pending] ?? 0) +
          (syncStates[SyncState.error] ?? 0);

      _addResult(DiagnosticResult(
        testName: 'Document Sync States',
        passed: unsyncedCount == 0,
        message: unsyncedCount == 0
            ? 'All ${documents.length} documents are synced'
            : '$unsyncedCount of ${documents.length} documents need syncing',
      ));

      // Show breakdown if there are issues
      if (unsyncedCount > 0) {
        syncStates.forEach((state, count) {
          if (state != SyncState.synced && count > 0) {
            _addResult(DiagnosticResult(
              testName: '  ${state.name} Documents',
              passed: false,
              message: '$count documents in ${state.name} state',
            ));
          }
        });
      }
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Document Sync States',
        passed: false,
        message: 'Error checking document states: $e',
      ));
    }
  }

  Future<void> _checkSyncQueue() async {
    try {
      final syncService = CloudSyncService();
      final syncStatus = await syncService.getSyncStatus();

      _addResult(DiagnosticResult(
        testName: 'Sync Queue',
        passed: syncStatus.pendingChanges == 0,
        message: syncStatus.pendingChanges == 0
            ? 'No pending sync operations'
            : '${syncStatus.pendingChanges} operations in queue',
        action: syncStatus.pendingChanges > 0 ? () => _forceSyncNow() : null,
      ));
    } catch (e) {
      _addResult(DiagnosticResult(
        testName: 'Sync Queue',
        passed: false,
        message: 'Error checking sync queue: $e',
      ));
    }
  }

  void _addResult(DiagnosticResult result) {
    setState(() {
      _results.add(result);
    });
  }

  Future<void> _forceCheckSubscription() async {
    try {
      final subscriptionService = sub.SubscriptionService();
      await subscriptionService.forceCheckPurchases();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking for purchases...')),
      );

      // Re-run subscription check after a delay
      await Future.delayed(const Duration(seconds: 2));
      await _checkSubscriptionStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking subscription: $e')),
      );
    }
  }

  Future<void> _resumeSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_paused', false);

      final syncService = CloudSyncService();
      await syncService.startSync();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync resumed')),
      );

      // Re-run sync settings check
      await _checkSyncSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resuming sync: $e')),
      );
    }
  }

  Future<void> _forceSyncNow() async {
    try {
      final syncService = CloudSyncService();
      await syncService.syncNow();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual sync triggered')),
      );

      // Re-run sync queue check after a delay
      await Future.delayed(const Duration(seconds: 3));
      await _checkSyncQueue();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error triggering sync: $e')),
      );
    }
  }

  void _showApiPluginFix() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Plugin Missing'),
        content: const Text(
          'The Amplify API plugin is required for cloud sync but is not configured.\n\n'
          'The API plugin has been added to the code. Please restart the app to apply this change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class DiagnosticResult {
  final String testName;
  final bool passed;
  final String message;
  final VoidCallback? action;

  DiagnosticResult({
    required this.testName,
    required this.passed,
    required this.message,
    this.action,
  });
}
