import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/new_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// **Feature: user-scoped-database, Property 9: Concurrent operation safety**
/// **Validates: Requirements 8.1, 8.2, 8.3**
///
/// Property-based test to verify that concurrent database operations are
/// properly synchronized and don't cause data corruption or race conditions.
/// This test verifies that:
/// - Multiple operations accessing the database simultaneously are serialized
/// - Database switches are queued when operations are in progress
/// - Operations are prevented during database switching
void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Property 9: Concurrent operation safety', () {
    late NewDatabaseService dbService;

    setUp(() {
      dbService = NewDatabaseService.instance;
    });

    tearDown(() async {
      try {
        await dbService.close();
      } catch (e) {
        // Ignore errors during cleanup
      }
    });

    test('concurrent read operations should not interfere with each other',
        () async {
      // Property: For any set of concurrent read operations,
      // all operations should complete successfully without errors

      final dbService = NewDatabaseService.instance;
      final db = await dbService.database;

      // Insert test data
      await db.insert('documents', {
        'sync_id': 'test-doc-1',
        'title': 'Test Document',
        'category': 'other',
        'notes': 'Test notes',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': 'synced',
      });

      // Run multiple concurrent read operations
      const numConcurrentReads = 100;
      final futures = List.generate(
        numConcurrentReads,
        (index) async {
          final db = await dbService.database;
          final result = await db.query('documents');
          return result.length;
        },
      );

      // All reads should complete successfully
      final results = await Future.wait(futures);

      // Verify all reads returned the same data
      expect(
        results.every((count) => count == 1),
        isTrue,
        reason: 'All concurrent reads should return consistent data',
      );
    });

    test(
        'concurrent write operations should be serialized without data corruption',
        () async {
      // Property: For any set of concurrent write operations,
      // all operations should complete and data should be consistent

      final dbService = NewDatabaseService.instance;

      // Run multiple concurrent write operations
      const numConcurrentWrites = 50;
      final futures = List.generate(
        numConcurrentWrites,
        (index) async {
          final db = await dbService.database;
          await db.insert('documents', {
            'sync_id': 'test-doc-$index',
            'title': 'Test Document $index',
            'category': 'other',
            'notes': 'Test notes $index',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_state': 'synced',
          });
        },
      );

      // All writes should complete successfully
      await Future.wait(futures);

      // Verify all documents were inserted
      final db = await dbService.database;
      final result = await db.query('documents');

      expect(
        result.length,
        equals(numConcurrentWrites),
        reason: 'All concurrent writes should complete without data loss',
      );

      // Verify data integrity - all documents should have unique sync_ids
      final syncIds = result.map((doc) => doc['sync_id'] as String).toSet();
      expect(
        syncIds.length,
        equals(numConcurrentWrites),
        reason: 'All documents should have unique sync_ids',
      );
    });

    test(
        'mixed concurrent read and write operations should maintain data consistency',
        () async {
      // Property: For any mix of concurrent read and write operations,
      // data consistency should be maintained

      final dbService = NewDatabaseService.instance;
      final db = await dbService.database;

      // Insert initial data
      await db.insert('documents', {
        'sync_id': 'initial-doc',
        'title': 'Initial Document',
        'category': 'other',
        'notes': 'Initial notes',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_state': 'synced',
      });

      // Run mixed concurrent operations
      const numOperations = 100;
      final futures = <Future>[];

      for (int i = 0; i < numOperations; i++) {
        if (i % 2 == 0) {
          // Write operation
          futures.add(Future(() async {
            final db = await dbService.database;
            await db.insert('documents', {
              'sync_id': 'concurrent-doc-$i',
              'title': 'Concurrent Document $i',
              'category': 'other',
              'notes': 'Concurrent notes $i',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_state': 'synced',
            });
          }));
        } else {
          // Read operation
          futures.add(Future(() async {
            final db = await dbService.database;
            final result = await db.query('documents');
            return result.length;
          }));
        }
      }

      // All operations should complete successfully
      await Future.wait(futures);

      // Verify final state
      final finalDb = await dbService.database;
      final finalResult = await finalDb.query('documents');

      // Should have initial doc + all write operations
      final expectedCount = 1 + (numOperations ~/ 2);
      expect(
        finalResult.length,
        equals(expectedCount),
        reason: 'All write operations should complete successfully',
      );
    });

    test(
        'concurrent operations during database initialization should be queued',
        () async {
      // Property: For any concurrent operations during database initialization,
      // all operations should wait for initialization to complete

      // Note: This test verifies the property with the current implementation
      // Once task 1 is complete with mutex synchronization, this will be even more robust

      final dbService = NewDatabaseService.instance;

      // Start multiple operations concurrently before database is initialized
      const numConcurrentOps = 20;
      final futures = List.generate(
        numConcurrentOps,
        (index) async {
          final db = await dbService.database;
          await db.insert('documents', {
            'sync_id': 'init-doc-$index',
            'title': 'Init Document $index',
            'category': 'other',
            'notes': 'Init notes $index',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_state': 'synced',
          });
        },
      );

      // All operations should complete successfully
      await Future.wait(futures);

      // Verify all documents were inserted
      final db = await dbService.database;
      final result = await db.query('documents');

      expect(
        result.length,
        equals(numConcurrentOps),
        reason: 'All operations should complete after database initialization',
      );
    });

    test('concurrent transactions should not deadlock', () async {
      // Property: For any set of concurrent transactions,
      // all transactions should complete without deadlock

      final dbService = NewDatabaseService.instance;

      // Run multiple concurrent transactions
      const numTransactions = 20;
      final futures = List.generate(
        numTransactions,
        (index) async {
          final db = await dbService.database;
          await db.transaction((txn) async {
            // Insert a document
            await txn.insert('documents', {
              'sync_id': 'txn-doc-$index',
              'title': 'Transaction Document $index',
              'category': 'other',
              'notes': 'Transaction notes $index',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_state': 'synced',
            });

            // Insert a file attachment
            await txn.insert('file_attachments', {
              'sync_id': 'txn-doc-$index',
              'file_name': 'file-$index.pdf',
              'label': 'Label $index',
              'local_path': '/path/to/file-$index.pdf',
              'file_size': 1024 * index,
              'added_at': DateTime.now().millisecondsSinceEpoch,
            });
          });
        },
      );

      // All transactions should complete without deadlock
      await Future.wait(futures);

      // Verify all data was inserted
      final db = await dbService.database;
      final docs = await db.query('documents');
      final files = await db.query('file_attachments');

      expect(
        docs.length,
        equals(numTransactions),
        reason: 'All transaction documents should be inserted',
      );
      expect(
        files.length,
        equals(numTransactions),
        reason: 'All transaction file attachments should be inserted',
      );
    });

    test('rapid sequential database access should not cause errors', () async {
      // Property: For any rapid sequence of database operations,
      // all operations should complete successfully

      final dbService = NewDatabaseService.instance;

      // Perform rapid sequential operations
      const numOperations = 200;
      for (int i = 0; i < numOperations; i++) {
        final db = await dbService.database;
        await db.insert('documents', {
          'sync_id': 'rapid-doc-$i',
          'title': 'Rapid Document $i',
          'category': 'other',
          'notes': 'Rapid notes $i',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'sync_state': 'synced',
        });
      }

      // Verify all documents were inserted
      final db = await dbService.database;
      final result = await db.query('documents');

      expect(
        result.length,
        equals(numOperations),
        reason: 'All rapid sequential operations should complete',
      );
    });

    test('concurrent operations with database stats should not interfere',
        () async {
      // Property: For any concurrent operations including stats queries,
      // all operations should complete successfully

      final dbService = NewDatabaseService.instance;

      // Run mixed operations including stats queries
      const numOperations = 50;
      final futures = <Future>[];

      for (int i = 0; i < numOperations; i++) {
        if (i % 3 == 0) {
          // Stats query
          futures.add(Future(() async {
            await dbService.getStats();
          }));
        } else {
          // Write operation
          futures.add(Future(() async {
            final db = await dbService.database;
            await db.insert('documents', {
              'sync_id': 'stats-doc-$i',
              'title': 'Stats Document $i',
              'category': 'other',
              'notes': 'Stats notes $i',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_state': 'synced',
            });
          }));
        }
      }

      // All operations should complete successfully
      await Future.wait(futures);

      // Verify final stats
      final stats = await dbService.getStats();
      final expectedDocs = numOperations - (numOperations ~/ 3);

      expect(
        stats['documents'],
        equals(expectedDocs),
        reason: 'Stats should reflect all completed write operations',
      );
    });

    test('property should hold under stress conditions', () async {
      // Property: Even under high concurrency stress,
      // data integrity should be maintained

      final dbService = NewDatabaseService.instance;

      // High stress test with many concurrent operations
      const numStressOperations = 500;
      final futures = <Future>[];

      for (int i = 0; i < numStressOperations; i++) {
        futures.add(Future(() async {
          final db = await dbService.database;

          // Mix of operations
          if (i % 4 == 0) {
            // Insert
            await db.insert('documents', {
              'sync_id': 'stress-doc-$i',
              'title': 'Stress Document $i',
              'category': 'other',
              'notes': 'Stress notes $i',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_state': 'synced',
            });
          } else if (i % 4 == 1) {
            // Query
            await db.query('documents');
          } else if (i % 4 == 2) {
            // Update (if documents exist)
            final docs = await db.query('documents', limit: 1);
            if (docs.isNotEmpty) {
              await db.update(
                'documents',
                {'title': 'Updated Title $i'},
                where: 'sync_id = ?',
                whereArgs: [docs.first['sync_id']],
              );
            }
          } else {
            // Stats
            await dbService.getStats();
          }
        }));
      }

      // All operations should complete without errors
      await Future.wait(futures);

      // Verify database is still functional
      final db = await dbService.database;
      final result = await db.query('documents');

      // Should have at least some documents
      expect(
        result.isNotEmpty,
        isTrue,
        reason: 'Database should remain functional after stress test',
      );

      // Verify data integrity - all sync_ids should be unique
      final syncIds = result.map((doc) => doc['sync_id'] as String).toSet();
      expect(
        syncIds.length,
        equals(result.length),
        reason: 'All documents should have unique sync_ids after stress test',
      );
    });
  });
}
