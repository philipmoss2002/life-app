import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';

import '../config/amplify_config.dart' as config;
import '../amplifyconfiguration.dart';
import 'security_config_service.dart';

// NOTE: ModelProvider.dart and amplifyconfiguration.dart are currently placeholders
// They will be replaced with real generated code when you run 'amplify push'

/// Service to initialize and manage AWS Amplify
class AmplifyService {
  static final AmplifyService _instance = AmplifyService._internal();
  factory AmplifyService() => _instance;
  AmplifyService._internal();

  bool _isConfigured = false;

  /// Check if Amplify is already configured
  bool get isConfigured => _isConfigured;

  /// Initialize AWS Amplify with the appropriate environment configuration
  Future<void> initialize() async {
    if (_isConfigured) {
      safePrint('Amplify is already configured');
      return;
    }

    try {
      // Configure security settings (TLS 1.3, certificate pinning)
      await SecurityConfigService().configureSecurity();

      // Add Amplify plugins
      await _addPlugins();

      // Configure Amplify
      // NOTE: Using placeholder config until 'amplify push' generates real configuration
      // After 'amplify push', this will use the generated amplifyconfiguration.dart
      if (amplifyconfig.isNotEmpty && amplifyconfig != '{}') {
        // Use generated configuration (after amplify push)
        await Amplify.configure(amplifyconfig);
      } else {
        // Use manual configuration (before amplify push)
        final amplifyConfig = config.AmplifyEnvironmentConfig.getConfig();
        final configJson = jsonEncode(amplifyConfig);
        await Amplify.configure(configJson);
      }

      _isConfigured = true;
      safePrint(
          'Amplify configured successfully for environment: ${config.AmplifyEnvironmentConfig.environment}');
    } on AmplifyAlreadyConfiguredException {
      _isConfigured = true;
      safePrint('Amplify was already configured');
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      rethrow;
    }
  }

  /// Add all required Amplify plugins
  Future<void> _addPlugins() async {
    try {
      // Add Auth plugin
      await Amplify.addPlugin(AmplifyAuthCognito());
      safePrint('Auth plugin added');

      // Add API plugin (required for GraphQL sync)
      await Amplify.addPlugin(AmplifyAPI());
      safePrint('API plugin added');

      // DataStore plugin removed - using local SQLite database instead

      // Add Storage plugin
      await Amplify.addPlugin(AmplifyStorageS3());
      safePrint('Storage plugin added');
    } catch (e) {
      safePrint('Error adding Amplify plugins: $e');
      rethrow;
    }
  }

  /// Reset Amplify configuration (useful for testing)
  Future<void> reset() async {
    _isConfigured = false;
  }

  /// Force reinitialize Amplify (for debugging)
  /// Note: This will only work if Amplify hasn't been configured yet in this session
  Future<void> forceReinitialize() async {
    if (Amplify.isConfigured) {
      safePrint(
          'Amplify is already configured in this session. App restart required for changes.');
      throw Exception(
          'Amplify already configured. Restart app to apply plugin changes.');
    }

    _isConfigured = false;
    await initialize();
  }
}
