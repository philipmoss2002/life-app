import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:household_docs_app/services/new_database_service.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NewDatabaseService', () {
    late NewDatabaseService dbService;

    setUp(() async {
      dbService = NewDatabaseService.instance;
    });

    tearDown(() async {
      await dbService.clearAllData();
      await dbService.close();
    });

    test('database initializes successfully', () async {
      final db = await dbService.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('documents table exists with correct schema', () async {
      final db = await dbService.database;

      // Query table info
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='documents'");

      expect(result, isNotEmpty);
      expect(result.first['name'], equals('documents'));

      // Verify columns
      final columns = await db.rawQuery('PRAGMA table_info(documents)');
      final columnNames = columns.map((col) => col['name']).toList();

      expect(columnNames, contains('sync_id'));
      expect(columnNames, contains('title'));
      expect(columnNames, contains('notes'));
      expect(columnNames, contains('labels'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
      expect(columnNames, contains('sync_state'));
    });

    test('file_attachments table exists with correct schema', () async {
      final db = await dbService.database;

      // Query table info
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='file_attachments'");

      expect(result, isNotEmpty);
      expect(result.first['name'], equals('file_attachments'));

      // Verify columns
      final columns = await db.rawQuery('PRAGMA table_info(file_attachments)');
      final columnNames = columns.map((col) => col['name']).toList();

      expect(columnNames, contains('id'));
      expect(columnNames, contains('sync_id'));
      expect(columnNames, contains('file_name'));
      expect(columnNames, contains('local_path'));
      expect(columnNames, contains('s3_key'));
      expect(columnNames, contains('file_size'));
      expect(columnNames, contains('added_at'));
    });

    test('logs table exists with correct schema', () async {
      final db = await dbService.database;

      // Query table info
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='logs'");

      expect(result, isNotEmpty);
      expect(result.first['name'], equals('logs'));

      // Verify columns
      final columns = await db.rawQuery('PRAGMA table_info(logs)');
      final columnNames = columns.map((col) => col['name']).toList();

      expect(columnNames, contains('id'));
      expect(columnNames, contains('timestamp'));
      expect(columnNames, contains('level'));
      expect(columnNames, contains('message'));
      expect(columnNames, contains('error_details'));
      expect(columnNames, contains('stack_trace'));
    });

    test('indexes are created correctly', () async {
      final db = await dbService.database;

      // Query indexes
      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'");

      final indexNames = indexes.map((idx) => idx['name']).toList();

      expect(indexNames, contains('idx_documents_sync_state'));
      expect(indexNames, contains('idx_file_attachments_sync_id'));
      expect(indexNames, contains('idx_logs_timestamp'));
      expect(indexNames, contains('idx_logs_level'));
    });

    test('foreign key constraint exists on file_attachments', () async {
      final db = await dbService.database;

      // Query foreign keys
      final foreignKeys =
          await db.rawQuery('PRAGMA foreign_key_list(file_attachments)');

      expect(foreignKeys, isNotEmpty);
      expect(foreignKeys.first['table'], equals('documents'));
      expect(foreignKeys.first['from'], equals('sync_id'));
      expect(foreignKeys.first['to'], equals('sync_id'));
      expect(foreignKeys.first['on_delete'], equals('CASCADE'));
    });

    test('getStats returns correct counts', () async {
      final stats = await dbService.getStats();

      expect(stats, isNotNull);
      expect(stats['documents'], equals(0));
      expect(stats['file_attachments'], equals(0));
      expect(stats['logs'], equals(0));
    });

    test('clearAllData removes all records', () async {
      final db = await dbService.database;

      // Insert test data
      await db.insert('documents', {
        'sync_id': 'test-uuid-1',
        'title': 'Test Document',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': 'synced',
      });

      await db.insert('logs', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'level': 'info',
        'message': 'Test log',
      });

      // Verify data exists
      var stats = await dbService.getStats();
      expect(stats['documents'], equals(1));
      expect(stats['logs'], equals(1));

      // Clear all data
      await dbService.clearAllData();

      // Verify data is cleared
      stats = await dbService.getStats();
      expect(stats['documents'], equals(0));
      expect(stats['logs'], equals(0));
    });

    test('cascade delete removes file attachments when document is deleted',
        () async {
      final db = await dbService.database;

      // Insert document
      await db.insert('documents', {
        'sync_id': 'test-uuid-1',
        'title': 'Test Document',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': 'synced',
      });

      // Insert file attachment
      await db.insert('file_attachments', {
        'sync_id': 'test-uuid-1',
        'file_name': 'test.pdf',
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Verify file attachment exists
      var fileResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM file_attachments');
      var fileCount = fileResult.first['count'] as int;
      expect(fileCount, equals(1));

      // Delete document
      await db.delete('documents',
          where: 'sync_id = ?', whereArgs: ['test-uuid-1']);

      // Verify file attachment is also deleted (cascade)
      fileResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM file_attachments');
      fileCount = fileResult.first['count'] as int;
      expect(fileCount, equals(0));
    });
  });
}
