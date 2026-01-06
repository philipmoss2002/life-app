import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:faker/faker.dart';
import 'package:household_docs_app/services/deletion_tracking_service.dart';
import 'package:household_docs_app/services/database_service.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

/// **Feature: sync-identifier-refactor, Property 5: Deletion Tombstone Preservation**
/// **Validates: Requirements 5.3, 5.4**
///
/// Property-based test to verify that deleted documents create tombstones with sync identifiers
/// that persist until purged, preventing document reinstatement during sync operations.
void main() {
  group('Property 5: Deletion Tombstone Preservation', () {
    late DeletionTrackingService deletionTrackingService;
    late DatabaseService databaseService;
    final faker = Faker();

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

    test(
        'tombstone should be created and preserved for any deleted document with sync identifier',
        () async {
      // Property: For any document with a sync identifier that is deleted,
      // a tombstone should be created and preserved until explicitly purged

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Generate random document with sync identifier
        final syncId = SyncIdentifierService.generateValidated();
        final userId = 'user-${faker.guid.guid()}';
        final deletedBy = 'device-${faker.randomGenerator.integer(999)}';
        final reason = faker.randomGenerator
            .element(['user', 'system', 'sync', 'cleanup']);

        final document = _createDocumentWithSyncId(
          title: faker.lorem.sentence(),
          syncId: syncId,
          userId: userId,
        );

        // Mark document for deletion
        await deletionTrackingService.markDocumentForDeletion(
          document,
          userId,
          deletedBy,
          reason: reason,
        );

        // Verify tombstone was created
        final isTombstoned =
            await deletionTrackingService.isDocumentTombstoned(syncId);
        expect(
          isTombstoned,
          isTrue,
          reason:
              'Tombstone should be created for deleted document with syncId: $syncId (iteration $i)',
        );

        // Verify tombstone contains correct information
        final tombstones =
            await deletionTrackingService.getUserTombstones(userId);
        final matchingTombstones =
            tombstones.where((t) => t['syncId'] == syncId).toList();

        expect(
          matchingTombstones.length,
          equals(1),
          reason:
              'Exactly one tombstone should exist for syncId: $syncId (iteration $i)',
        );

        final tombstone = matchingTombstones.first;
        expect(
          tombstone['syncId'],
          equals(syncId),
          reason:
              'Tombstone should preserve the sync identifier (iteration $i)',
        );
        expect(
          tombstone['userId'],
          equals(userId),
          reason:
              'Tombstone should preserve the user identifier (iteration $i)',
        );
        expect(
          tombstone['deletedBy'],
          equals(deletedBy),
          reason:
              'Tombstone should preserve the deletedBy information (iteration $i)',
        );
        expect(
          tombstone['reason'],
          equals(reason),
          reason:
              'Tombstone should preserve the deletion reason (iteration $i)',
        );

        // Clean up for next iteration
        final db = await databaseService.database;
        await db.delete('document_tombstones');
        await db.delete('documents');
      }
    });

    test(
        'tombstone should prevent document reinstatement during sync operations',
        () async {
      // Property: For any document with a tombstone, sync operations should
      // filter out that document to prevent reinstatement

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Generate random documents, some with tombstones
        final numDocuments = faker.randomGenerator.integer(10, min: 3);
        final documents = <Document>[];
        final tombstonedSyncIds = <String>{};

        for (int j = 0; j < numDocuments; j++) {
          final syncId = SyncIdentifierService.generateValidated();
          final userId = 'user-${faker.guid.guid()}';

          final document = _createDocumentWithSyncId(
            title: faker.lorem.sentence(),
            syncId: syncId,
            userId: userId,
          );
          documents.add(document);

          // Randomly tombstone some documents
          if (faker.randomGenerator.boolean()) {
            await databaseService.createTombstone(
              syncId,
              userId,
              'device-${faker.randomGenerator.integer(999)}',
              reason: 'user',
            );
            tombstonedSyncIds.add(syncId);
          }
        }

        // Filter documents through tombstone check
        final filteredDocuments =
            await deletionTrackingService.filterTombstonedDocuments(documents);

        // Verify that tombstoned documents were filtered out
        for (final document in filteredDocuments) {
          final syncId = _extractSyncId(document);
          expect(
            tombstonedSyncIds.contains(syncId),
            isFalse,
            reason:
                'Filtered documents should not contain tombstoned syncId: $syncId (iteration $i)',
          );
        }

        // Verify that non-tombstoned documents were preserved
        final filteredSyncIds = filteredDocuments
            .map((doc) => _extractSyncId(doc))
            .where((id) => id != null)
            .toSet();

        final expectedSyncIds = documents
            .map((doc) => _extractSyncId(doc))
            .where((id) => id != null && !tombstonedSyncIds.contains(id))
            .toSet();

        expect(
          filteredSyncIds,
          equals(expectedSyncIds),
          reason:
              'All non-tombstoned documents should be preserved (iteration $i)',
        );

        // Clean up for next iteration
        final db = await databaseService.database;
        await db.delete('document_tombstones');
        await db.delete('documents');
      }
    });

    test('tombstone should persist until explicitly purged', () async {
      // Property: For any tombstone created, it should persist through
      // multiple sync operations until explicitly purged by cleanup

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final userId = 'user-${faker.guid.guid()}';
        final deletedBy = 'device-${faker.randomGenerator.integer(999)}';

        // Create tombstone
        await databaseService.createTombstone(syncId, userId, deletedBy);

        // Verify tombstone exists
        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isTrue,
          reason: 'Tombstone should exist after creation (iteration $i)',
        );

        // Simulate multiple sync operations that should not affect tombstone
        final numSyncOperations = faker.randomGenerator.integer(20, min: 5);

        for (int j = 0; j < numSyncOperations; j++) {
          // Create documents that might be filtered
          final testDocuments = List.generate(
            faker.randomGenerator.integer(5, min: 1),
            (index) => _createDocumentWithSyncId(
              title: faker.lorem.sentence(),
              syncId: SyncIdentifierService.generateValidated(), userId: userId,
            ),
          );

          // Add the tombstoned document to the list
          testDocuments.add(_createDocumentWithSyncId(
            title: faker.lorem.sentence(),
            syncId: syncId,
            userId: userId,
          ));

          // Filter documents - tombstoned document should be removed
          final filtered = await deletionTrackingService
              .filterTombstonedDocuments(testDocuments);

          // Verify tombstoned document was filtered out
          final filteredSyncIds =
              filtered.map((doc) => _extractSyncId(doc)).toSet();
          expect(
            filteredSyncIds.contains(syncId),
            isFalse,
            reason:
                'Tombstoned document should be filtered out in sync operation $j (iteration $i)',
          );

          // Verify tombstone still exists after filtering operation
          expect(
            await deletionTrackingService.isDocumentTombstoned(syncId),
            isTrue,
            reason:
                'Tombstone should persist through sync operation $j (iteration $i)',
          );
        }

        // Tombstone should still exist after all sync operations
        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isTrue,
          reason:
              'Tombstone should persist through all sync operations (iteration $i)',
        );

        // Clean up for next iteration
        final db = await databaseService.database;
        await db.delete('document_tombstones');
      }
    });

    test('tombstone should be purged only by explicit cleanup operations',
        () async {
      // Property: For any tombstone, it should only be removed by explicit
      // cleanup operations based on age, not by regular sync operations

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final userId = 'user-${faker.guid.guid()}';
        final deletedBy = 'device-${faker.randomGenerator.integer(999)}';

        // Create tombstone
        await databaseService.createTombstone(syncId, userId, deletedBy);

        // Verify tombstone exists
        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isTrue,
          reason: 'Tombstone should exist after creation (iteration $i)',
        );

        // Simulate various operations that should NOT purge the tombstone
        await _simulateNonPurgingOperations(
            deletionTrackingService, syncId, userId);

        // Tombstone should still exist after non-purging operations
        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isTrue,
          reason:
              'Tombstone should survive non-purging operations (iteration $i)',
        );

        // Now test explicit cleanup - create an old tombstone by direct DB manipulation
        final db = await databaseService.database;
        final oldDate = DateTime.now().subtract(const Duration(days: 100));

        // Update the tombstone to be old
        await db.update(
          'document_tombstones',
          {'deletedAt': oldDate.toIso8601String()},
          where: 'syncId = ?',
          whereArgs: [syncId],
        );

        // Run cleanup operation
        final deletedCount =
            await deletionTrackingService.cleanupOldTombstones();

        // Verify old tombstone was purged
        expect(
          deletedCount,
          greaterThanOrEqualTo(1),
          reason: 'Cleanup should purge old tombstones (iteration $i)',
        );

        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isFalse,
          reason: 'Old tombstone should be purged by cleanup (iteration $i)',
        );

        // Clean up for next iteration
        await db.delete('document_tombstones');
      }
    });

    test('tombstone preservation should handle concurrent operations',
        () async {
      // Property: For any tombstone, it should be preserved correctly
      // even when multiple operations occur concurrently

      const iterations = 20;

      for (int i = 0; i < iterations; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final userId = 'user-${faker.guid.guid()}';
        final deletedBy = 'device-${faker.randomGenerator.integer(999)}';

        // Create tombstone
        await databaseService.createTombstone(syncId, userId, deletedBy);

        // Simulate concurrent operations
        final futures = <Future>[];

        // Multiple tombstone checks
        for (int j = 0; j < 10; j++) {
          futures.add(deletionTrackingService.isDocumentTombstoned(syncId));
        }

        // Multiple document filtering operations
        for (int j = 0; j < 5; j++) {
          final testDoc = _createDocumentWithSyncId(
            title: faker.lorem.sentence(),
            syncId: syncId,
            userId: userId,
          );
          futures.add(
              deletionTrackingService.filterTombstonedDocuments([testDoc]));
        }

        // Multiple tombstone queries
        for (int j = 0; j < 3; j++) {
          futures.add(deletionTrackingService.getUserTombstones(userId));
        }

        // Wait for all concurrent operations
        final results = await Future.wait(futures);

        // Verify all tombstone checks returned true
        final tombstoneChecks = results.take(10).cast<bool>();
        for (final check in tombstoneChecks) {
          expect(
            check,
            isTrue,
            reason:
                'Concurrent tombstone checks should all return true (iteration $i)',
          );
        }

        // Verify all filtering operations removed the tombstoned document
        final filterResults = results.skip(10).take(5).cast<List<Document>>();
        for (final filtered in filterResults) {
          expect(
            filtered.isEmpty,
            isTrue,
            reason:
                'Concurrent filtering should remove tombstoned documents (iteration $i)',
          );
        }

        // Verify tombstone still exists after concurrent operations
        expect(
          await deletionTrackingService.isDocumentTombstoned(syncId),
          isTrue,
          reason:
              'Tombstone should survive concurrent operations (iteration $i)',
        );

        // Clean up for next iteration
        final db = await databaseService.database;
        await db.delete('document_tombstones');
      }
    });
  });
}

/// Helper function to create a document with a specific sync ID
Document _createDocumentWithSyncId({
  required String title,
  required String syncId,
  required String userId,
}) {
  final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

    userId: userId,
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

/// Helper function to extract sync ID from document
String? _extractSyncId(Document document) {
  try {
    final docMap = document.toJson();
    return docMap['syncId'] as String?;
  } catch (e) {
    return null;
  }
}

/// Helper function to simulate operations that should NOT purge tombstones
Future<void> _simulateNonPurgingOperations(
  DeletionTrackingService service,
  String syncId,
  String userId,
) async {
  // Simulate document filtering operations
  final testDoc = _createDocumentWithSyncId(
    title: 'Test Document',
    syncId: syncId,
    userId: userId,
  );

  await service.filterTombstonedDocuments([testDoc]);

  // Simulate tombstone checks
  await service.isDocumentTombstoned(syncId);

  // Simulate getting user tombstones
  await service.getUserTombstones(userId);

  // Simulate getting documents pending deletion
  await service.getDocumentsPendingDeletion(userId);
}
