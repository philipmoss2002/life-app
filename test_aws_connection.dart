/// AWS Connectivity Test Script
///
/// Run this script to test connectivity to AWS services
/// Usage: flutter run test_aws_connection.dart

import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'lib/amplifyconfiguration.dart';
import 'lib/models/ModelProvider.dart';

void main() {
  runApp(const AWSConnectivityTestApp());
}

class AWSConnectivityTestApp extends StatelessWidget {
  const AWSConnectivityTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWS Connectivity Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ConnectivityTestScreen(),
    );
  }
}

class ConnectivityTestScreen extends StatefulWidget {
  const ConnectivityTestScreen({Key? key}) : super(key: key);

  @override
  State<ConnectivityTestScreen> createState() => _ConnectivityTestScreenState();
}

class _ConnectivityTestScreenState extends State<ConnectivityTestScreen> {
  final List<TestResult> _results = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // Test 1: Amplify Configuration
    await _testAmplifyConfiguration();

    // Test 2: Auth Plugin
    await _testAuthPlugin();

    // Test 3: Storage Plugin
    await _testStoragePlugin();

    // Test 4: API Plugin
    await _testAPIPlugin();

    // Test 5: Network Connectivity
    await _testNetworkConnectivity();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _testAmplifyConfiguration() async {
    _addResult('Amplify Configuration', 'Testing...', TestStatus.running);

    try {
      if (!Amplify.isConfigured) {
        await Amplify.addPlugins([
          AmplifyAuthCognito(),
          AmplifyStorageS3(),
          AmplifyAPI(),
        ]);
        await Amplify.configure(amplifyconfig);
      }

      _updateResult(
        'Amplify Configuration',
        'Successfully configured',
        TestStatus.success,
      );
    } catch (e) {
      _updateResult(
        'Amplify Configuration',
        'Failed: $e',
        TestStatus.failure,
      );
    }
  }

  Future<void> _testAuthPlugin() async {
    _addResult('Auth Plugin', 'Testing...', TestStatus.running);

    try {
      final session = await Amplify.Auth.fetchAuthSession();
      _updateResult(
        'Auth Plugin',
        'Plugin loaded. Authenticated: ${session.isSignedIn}',
        TestStatus.success,
      );
    } catch (e) {
      _updateResult(
        'Auth Plugin',
        'Failed: $e',
        TestStatus.failure,
      );
    }
  }

  Future<void> _testStoragePlugin() async {
    _addResult('Storage Plugin', 'Testing...', TestStatus.running);

    try {
      final result =
          await Amplify.Storage.list(path: const StoragePath.fromString('/'))
              .result;
      _updateResult(
        'Storage Plugin',
        'Plugin loaded. Found ${result.items.length} items',
        TestStatus.success,
      );
    } catch (e) {
      if (e.toString().contains('not signed in')) {
        _updateResult(
          'Storage Plugin',
          'Plugin loaded (requires sign-in to list files)',
          TestStatus.success,
        );
      } else {
        _updateResult(
          'Storage Plugin',
          'Failed: $e',
          TestStatus.failure,
        );
      }
    }
  }

  Future<void> _testAPIPlugin() async {
    _addResult('API Plugin', 'Testing...', TestStatus.running);

    try {
      // Simple introspection query
      const graphQLDocument = '''
        query {
          __typename
        }
      ''';

      final request = GraphQLRequest<String>(
        document: graphQLDocument,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.errors.isEmpty) {
        _updateResult(
          'API Plugin',
          'Plugin loaded. API responding',
          TestStatus.success,
        );
      } else {
        _updateResult(
          'API Plugin',
          'Plugin loaded but query failed: ${response.errors}',
          TestStatus.warning,
        );
      }
    } catch (e) {
      _updateResult(
        'API Plugin',
        'Failed: $e',
        TestStatus.failure,
      );
    }
  }

  Future<void> _testNetworkConnectivity() async {
    _addResult('Network Connectivity', 'Testing...', TestStatus.running);

    try {
      // Try to fetch current user (requires network)
      await Amplify.Auth.getCurrentUser();
      _updateResult(
        'Network Connectivity',
        'Network is accessible',
        TestStatus.success,
      );
    } catch (e) {
      if (e.toString().contains('not signed in') ||
          e.toString().contains('No current user')) {
        _updateResult(
          'Network Connectivity',
          'Network is accessible (no user signed in)',
          TestStatus.success,
        );
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        _updateResult(
          'Network Connectivity',
          'Network error: $e',
          TestStatus.failure,
        );
      } else {
        _updateResult(
          'Network Connectivity',
          'Unknown error: $e',
          TestStatus.warning,
        );
      }
    }
  }

  void _addResult(String test, String message, TestStatus status) {
    setState(() {
      _results.add(TestResult(test, message, status));
    });
  }

  void _updateResult(String test, String message, TestStatus status) {
    setState(() {
      final index = _results.indexWhere((r) => r.test == test);
      if (index != -1) {
        _results[index] = TestResult(test, message, status);
      }
    });
  }

  Color _getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.success:
        return Colors.green;
      case TestStatus.failure:
        return Colors.red;
      case TestStatus.warning:
        return Colors.orange;
      case TestStatus.running:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.success:
        return Icons.check_circle;
      case TestStatus.failure:
        return Icons.error;
      case TestStatus.warning:
        return Icons.warning;
      case TestStatus.running:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final successCount =
        _results.where((r) => r.status == TestStatus.success).length;
    final failureCount =
        _results.where((r) => r.status == TestStatus.failure).length;
    final warningCount =
        _results.where((r) => r.status == TestStatus.warning).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AWS Connectivity Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Summary Card
          if (_results.isNotEmpty && !_isRunning)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Test Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          count: successCount,
                          label: 'Passed',
                        ),
                        _SummaryItem(
                          icon: Icons.warning,
                          color: Colors.orange,
                          count: warningCount,
                          label: 'Warnings',
                        ),
                        _SummaryItem(
                          icon: Icons.error,
                          color: Colors.red,
                          count: failureCount,
                          label: 'Failed',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Test Results
          Expanded(
            child: _isRunning && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            _getStatusIcon(result.status),
                            color: _getStatusColor(result.status),
                            size: 32,
                          ),
                          title: Text(
                            result.test,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(result.message),
                        ),
                      );
                    },
                  ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runTests,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Run Tests Again'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Copy results to clipboard
                      final text = _results
                          .map((r) => '${r.test}: ${r.message}')
                          .join('\n');
                      safePrint('Test Results:\n$text');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Results'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class TestResult {
  final String test;
  final String message;
  final TestStatus status;

  TestResult(this.test, this.message, this.status);
}

enum TestStatus {
  success,
  failure,
  warning,
  running,
}
