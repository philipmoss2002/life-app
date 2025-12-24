import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:household_docs_app/providers/auth_provider.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/models/FileAttachment.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

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

/// Test helper class with utility methods
class TestHelpers {
  static final Random _random = Random();

  /// Create a random number generator for tests
  static Random createRandom() => _random;

  /// Create a random document for testing
  static Document createRandomDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), {,
    String? id,
    String? userId,
    String? title,
    String? category,
    List<String>? filePaths,
    String? notes,
  }) {
    final createdAt = TemporalDateTime(
        DateTime.now().subtract(Duration(days: _random.nextInt(30))));
    final lastModified = TemporalDateTime(
        DateTime.now().subtract(Duration(hours: _random.nextInt(24))));

    return Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

            userId: userId ?? 'test_user_${_random.nextInt(1000)}',
      title: title ?? 'Test Document ${_random.nextInt(1000)}',
      category: category ?? 'Test Category ${_random.nextInt(100)}',
      filePaths: filePaths ?? ['test_file_${_random.nextInt(100)}.pdf'],
      renewalDate: _random.nextBool()
          ? TemporalDateTime(
              DateTime.now().add(Duration(days: _random.nextInt(365))))
          : null,
      notes: notes ??
          (_random.nextBool() ? 'Test notes ${_random.nextInt(100)}' : null),
      createdAt: createdAt,
      lastModified: lastModified,
      version: _random.nextInt(10) + 1,
      syncState:
          SyncState.values[_random.nextInt(SyncState.values.length)].toJson(),
      conflictId:
          _random.nextBool() ? 'conflict_${_random.nextInt(100)}' : null,
      deleted: _random.nextBool() ? _random.nextBool() : false,
      deletedAt: _random.nextBool()
          ? TemporalDateTime(
              DateTime.now().subtract(Duration(days: _random.nextInt(7))))
          : null,
    );
  }

  /// Create a list of random documents
  static List<Document> createRandomDocuments(int count, {String? userId}) {
    return List.generate(
        count,
        (index) => createRandomDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

                            userId: userId,
            ));
  }

  /// Create a random FileAttachment for testing
  static FileAttachment createRandomFileAttachment({
    String? id,
    String? filePath,
    String? fileName,
    String? label,
    int? fileSize,
    String? s3Key,
    amplify_core.TemporalDateTime? addedAt,
    String? syncState,
  }) {
    return FileAttachment(
            filePath: filePath ?? '/test/path/file_${_random.nextInt(100)}.pdf',
      fileName: fileName ?? 'test_file_${_random.nextInt(100)}.pdf',
      label: label ??
          (_random.nextBool() ? 'Test Label ${_random.nextInt(100)}' : null),
      fileSize: fileSize ?? _random.nextInt(10000000) + 1024,
      s3Key: s3Key ?? 's3://bucket/key_${_random.nextInt(1000)}',
      addedAt: addedAt ??
          amplify_core.TemporalDateTime(
              DateTime.now().subtract(Duration(hours: _random.nextInt(24)))),
      syncState: syncState ??
          SyncState.values[_random.nextInt(SyncState.values.length)].toJson(),
    );
  }

  /// Create a random string
  static String createRandomString([int length = 10]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  /// Create a random file path
  static String createRandomFilePath() {
    final extensions = ['.pdf', '.jpg', '.png', '.doc', '.txt'];
    final extension = extensions[_random.nextInt(extensions.length)];
    return '/test/files/${createRandomString(8)}$extension';
  }
}
