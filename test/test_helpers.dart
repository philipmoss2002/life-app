import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
