import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:household_docs_app/services/deletion_tracking_service.dart';
import 'package:household_docs_app/services/database_service.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

void main() {
  group('DeletionTrackingService', () {
    late DeletionTrackingService deletionTrackingService;
    late DatabaseService databaseService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      deletionTrackingService = DeletionTrackingService();
      databaseService = DatabaseService.instance;

      // Clean up database between tests
      final db = await databaseService.database;
      await db.delete('document_tombstones');
      await db.delete('documents');
      await db.delete('file_attachments');
    });

    group('Tombstone Creation', () {
      test('should create tombstone for document with sync identifier',
          () async {
        // Create a test document with sync identifier
        final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

          userId: 'test-user-123',
          title: 'Test Document',
          category: 'Test',
          filePaths: [],
          createdAt: amplify_core.TemporalDateTime.now(),
          lastModified: amplify_core.TemporalDateTime.now(),
          version: 1,
          syncState: SyncState.synced.toJson(),
        );

        // Add syncId to the document (simulating a document with sync identifier)
        final testSyncId = SyncIdentifierService.generateValidated();
        final documentWithSyncId = document.copyWith();
        final docMap = documentWithSyncId.toJson();
        docMap['syncId'] = testSyncId;
        final testDocument = Document.fromJson(docMap);

        // Mark document for deletion
        await deletionTrackingService.markDocumentForDeletion(
          testDocument,
          'test-user-123',
          'test-device',
          reason: 'user',
        );

        // Verify tombstone was created
        final isTombstoned =
            await deletionTrackingService.isDocumentTombstoned(testSyncId);
        expect(isTombstoned, isTrue);

        // Verify tombstone details
        final tombstones =
            await deletionTrackingService.getUserTombstones('test-user-123');
        expect(tombstones.length, equals(1));
        expect(tombstones.first['syncId'], equals(testSyncId));
        expect(tombstones.first['userId'], equals('test-user-123'));
        expect(tombstones.first['deletedBy'], equals('test-device'));
        expect(tombstones.first['reason'], equals('user'));
      });

      test('should not create duplicate tombstones', () async {
        final syncId = SyncIdentifierService.generateValidated();

        // Create tombstone directly
        await databaseService.createTombstone(syncId, 'test-user', 'device1');

        // Create a test document
        final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

          userId: 'test-user',
          title: 'Test Document',
          category: 'Test',
          filePaths: [],
          createdAt: amplify_core.TemporalDateTime.now(),
          lastModified: amplify_core.TemporalDateTime.now(),
          version: 1,
          syncState: SyncState.synced.toJson(),
        );

        final docMap = document.toJson();
        docMap['syncId'] = syncId;
        final testDocument = Document.fromJson(docMap);

        // Try to mark for deletion again
        await deletionTrackingService.markDocumentForDeletion(
          testDocument,
          'test-user',
          'device2',
        );

        // Should still have only one tombstone
        final tombstones =
            await deletionTrackingService.getUserTombstones('test-user');
        final matchingTombstones =
            tombstones.where((t) => t['syncId'] == syncId).toList();
        expect(matchingTombstones.length, equals(1));
      });
    });

    group('Tombstone Filtering', () {
      test('should filter out tombstoned documents from sync', () async {
        const syncId1 = 'sync-id-1';
        const syncId2 = 'sync-id-2';
        const syncId3 = 'sync-id-3';

        // Create tombstone for first document
        await databaseService.createTombstone(syncId1, 'test-user', 'device');

        // Create test documents
        final documents = [
          _createDocumentWithSyncId('doc1', syncId1),
          _createDocumentWithSyncId('doc2', syncId2),
          _createDocumentWithSyncId('doc3', syncId3),
        ];

        // Filter documents
        final filteredDocuments =
            await deletionTrackingService.filterTombstonedDocuments(documents);

        // Should have filtered out the first document
        expect(filteredDocuments.length, equals(2));
        expect(filteredDocuments.any((doc) => doc.title == 'doc1'), isFalse);
        expect(filteredDocuments.any((doc) => doc.title == 'doc2'), isTrue);
        expect(filteredDocuments.any((doc) => doc.title == 'doc3'), isTrue);
      });

      test('should handle documents without sync identifiers', () async {
        // Create documents without sync identifiers
        final documents = [
          Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

            userId: 'test-user',
            title: 'No Sync ID Doc',
            category: 'Test',
            filePaths: [],
            createdAt: amplify_core.TemporalDateTime.now(),
            lastModified: amplify_core.TemporalDateTime.now(),
            version: 1,
            syncState: SyncState.notSynced.toJson(),
          ),
        ];

        // Filter documents (should not filter out documents without sync IDs)
        final filteredDocuments =
            await deletionTrackingService.filterTombstonedDocuments(documents);
        expect(filteredDocuments.length, equals(1));
      });
    });

    group('Tombstone Cleanup', () {
      test('should clean up old tombstones', () async {
        // Create an old tombstone by directly inserting into database
        final db = await databaseService.database;
        final oldDate = DateTime.now().subtract(const Duration(days: 100));

        await db.insert('document_tombstones', {
          'syncId': 'old-tombstone',
          'userId': 'test-user',
          'deletedAt': oldDate.toIso8601String(),
          'deletedBy': 'test-device',
          'reason': 'user',
        });

        // Create a recent tombstone
        await databaseService.createTombstone(
            'recent-tombstone', 'test-user', 'test-device');

        // Run cleanup
        final deletedCount =
            await deletionTrackingService.cleanupOldTombstones();

        // Should have deleted the old tombstone
        expect(deletedCount, equals(1));

        // Verify old tombstone is gone but recent one remains
        final isOldTombstoned =
            await deletionTrackingService.isDocumentTombstoned('old-tombstone');
        final isRecentTombstoned = await deletionTrackingService
            .isDocumentTombstoned('recent-tombstone');

        expect(isOldTombstoned, isFalse);
        expect(isRecentTombstoned, isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle invalid sync identifiers gracefully', () async {
        final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

          userId: 'test-user',
          title: 'Test Document',
          category: 'Test',
          filePaths: [],
          createdAt: amplify_core.TemporalDateTime.now(),
          lastModified: amplify_core.TemporalDateTime.now(),
          version: 1,
          syncState: SyncState.synced.toJson(),
        );

        // Add invalid syncId
        final docMap = document.toJson();
        docMap['syncId'] = 'invalid-sync-id-format';
        final testDocument = Document.fromJson(docMap);

        // Should not throw error - invalid sync IDs are now handled gracefully
        await deletionTrackingService.markDocumentForDeletion(
          testDocument,
          'test-user',
          'test-device',
        );

        // Should create tombstone even with invalid format
        final isTombstoned = await deletionTrackingService
            .isDocumentTombstoned('invalid-sync-id-format');
        expect(isTombstoned, isTrue);
      });

      test('should handle empty user ID', () async {
        final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

          userId: 'test-user',
          title: 'Test Document',
          category: 'Test',
          filePaths: [],
          createdAt: amplify_core.TemporalDateTime.now(),
          lastModified: amplify_core.TemporalDateTime.now(),
          version: 1,
          syncState: SyncState.synced.toJson(),
        );

        // Should throw ArgumentError for empty user ID
        expect(
          () => deletionTrackingService.markDocumentForDeletion(
            document,
            '', // Empty user ID
            'test-device',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}

/// Helper function to create a document with a specific sync ID
Document _createDocumentWithSyncId(String title, String syncId) {
  final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

    userId: 'test-user',
    title: title,
    category: 'Test',
    filePaths: [],
    createdAt: amplify_core.TemporalDateTime.now(),
    lastModified: amplify_core.TemporalDateTime.now(),
    version: 1,
    syncState: SyncState.synced.toJson(),
  );

  final docMap = document.toJson();
  docMap['syncId'] = syncId;
  return Document.fromJson(docMap);
}
