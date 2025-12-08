import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:household_docs_app/providers/auth_provider.dart';

/// Initialize the database factory for testing
/// This must be called before any tests that use the database
void setupTestDatabase() {
  // Initialize FFI
  sqfliteFfiInit();

  // Set the database factory for testing
  databaseFactory = databaseFactoryFfi;
}

/// Setup function to be called in setUpAll for widget tests
void setupWidgetTest() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupTestDatabase();
}

/// Wraps a widget with necessary providers for testing
Widget wrapWithProviders(Widget child) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}
