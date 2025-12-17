import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test'),
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
                    onPressed: _isRunning ? null : _testAmplifyAPI,
                    child: _isRunning
                        ? const Text('Testing API...')
                        : const Text('Test Amplify API'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _testAuthentication,
                    child: _isRunning
                        ? const Text('Testing Auth...')
                        : const Text('Test Authentication'),
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
    debugPrint('API_TEST: $message');
  }

  Future<void> _testAmplifyAPI() async {
    setState(() => _isRunning = true);
    _log('🔍 Testing Amplify API configuration...');

    try {
      // Test 1: Check if Amplify is configured
      _log('📋 Step 1: Checking Amplify configuration...');
      if (!Amplify.isConfigured) {
        _log('❌ Amplify is not configured');
        return;
      }
      _log('✅ Amplify is configured');

      // Test 2: Check if API plugin is available
      _log('📋 Step 2: Checking API plugin...');
      try {
        // Try a simple GraphQL query to test API connectivity
        const testQuery = '''
          query ListDocuments {
            listDocuments {
              items {
                id
                title
              }
            }
          }
        ''';

        final request = GraphQLRequest<String>(
          document: testQuery,
        );

        _log('📤 Sending test GraphQL query...');
        final response = await Amplify.API.query(request: request).response;

        _log('📨 GraphQL response received');
        _log('❓ Has errors: ${response.hasErrors}');

        if (response.hasErrors) {
          _log(
              '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
        } else {
          _log('✅ API plugin is working correctly');
          _log('📄 Response data available: ${response.data != null}');
        }
      } catch (e) {
        _log('❌ API plugin test failed: $e');
      }
    } catch (e) {
      _log('❌ API test failed: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _testAuthentication() async {
    setState(() => _isRunning = true);
    _log('🔍 Testing authentication...');

    try {
      // Test authentication status
      _log('📋 Checking authentication status...');

      final user = await Amplify.Auth.getCurrentUser();
      _log('✅ User authenticated');
      _log('👤 User ID: ${user.userId}');
      _log('📧 Username: ${user.username}');

      // Test session validity
      _log('📋 Checking session validity...');
      final session = await Amplify.Auth.fetchAuthSession();
      _log('✅ Session is valid: ${session.isSignedIn}');

      if (session is CognitoAuthSession) {
        _log(
            '🔑 Access token available: ${session.userPoolTokensResult.value.accessToken.raw.isNotEmpty}');
        _log(
            '🔑 ID token available: ${session.userPoolTokensResult.value.idToken.raw.isNotEmpty}');
      }
    } catch (e) {
      _log('❌ Authentication test failed: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }
}
