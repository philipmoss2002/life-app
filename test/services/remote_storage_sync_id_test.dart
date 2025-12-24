import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import '../../lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

void main() {
  group('Remote Storage Sync ID Integration', () {
    test('Document should be created with sync identifier', () {
      // Generate a sync identifier
      final syncId = SyncIdentifierService.generateValidated();

      // Create a document with sync identifier
      final document = Document(syncId: syncId, userId: 'test-user-123', title: 'Test Document', category: 'Home Insurance', filePaths: [], createdAt: amplify_core.TemporalDateTime.now(, lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      // Verify document has sync identifier
      expect(document.syncId, equals(syncId));
      expect(SyncIdentifierGenerator.isValid(document.syncId!), isTrue);
    });

    test('Document sync identifier should be immutable', () {
      final originalSyncId = SyncIdentifierService.generateValidated();

      final document = Document(syncId: originalSyncId, userId: 'test-user-123', title: 'Test Document', category: 'Home Insurance', filePaths: [], createdAt: amplify_core.TemporalDateTime.now(, lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      // Create a copy with updated fields but same sync ID
      final updatedDocument = document.copyWith(
        title: 'Updated Title',
        version: 2,
      );

      // Verify sync identifier remains the same
      expect(updatedDocument.syncId, equals(originalSyncId));
      expect(updatedDocument.title, equals('Updated Title'));
      expect(updatedDocument.version, equals(2));
    });

    test('Document should validate sync identifier format', () {
      // Valid sync identifier
      final validSyncId = SyncIdentifierService.generateValidated();
      expect(SyncIdentifierGenerator.isValid(validSyncId), isTrue);

      // Invalid sync identifiers
      expect(SyncIdentifierGenerator.isValid(''), isFalse);
      expect(SyncIdentifierGenerator.isValid('invalid-uuid'), isFalse);
      expect(
          SyncIdentifierGenerator.isValid(
              '12345678-1234-1234-1234-123456789012'),
          isFalse); // Not v4
    });

    test('Document should support sync identifier normalization', () {
      final uppercaseSyncId = 'A1B2C3D4-E5F6-4789-A1B2-C3D4E5F67890';
      final normalizedSyncId =
          SyncIdentifierGenerator.normalize(uppercaseSyncId);

      expect(normalizedSyncId, equals('a1b2c3d4-e5f6-4789-a1b2-c3d4e5f67890'));
      expect(SyncIdentifierGenerator.isValid(normalizedSyncId), isTrue);
    });

    test('Document collection should have unique sync identifiers', () {
      final documents = <Document>[];
      final syncIds = <String>{};

      // Create multiple documents with unique sync identifiers
      for (int i = 0; i < 10; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final document = Document(syncId: syncId, userId: 'test-user-123', title: 'Test Document $i', category: 'Home Insurance', filePaths: [], createdAt: amplify_core.TemporalDateTime.now(, lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          lastModified: amplify_core.TemporalDateTime.now(),
          version: 1,
          syncState: SyncState.notSynced.toJson(),
        );

        documents.add(document);
        syncIds.add(syncId);
      }

      // Verify all sync identifiers are unique
      expect(documents.length, equals(10));
      expect(syncIds.length,
          equals(10)); // Set should have same size if all unique

      // Verify each document has a valid sync identifier
      for (final document in documents) {
        expect(document.syncId, isNotNull);
        expect(SyncIdentifierGenerator.isValid(document.syncId!), isTrue);
      }
    });

    test('Document should support sync identifier-based matching', () {
      final syncId = SyncIdentifierService.generateValidated();

      final document1 = Document(syncId: syncId, userId: 'test-user-123', title: 'Original Title', category: 'Home Insurance', filePaths: [], createdAt: amplify_core.TemporalDateTime.now(, lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final document2 = Document(syncId: syncId, userId: 'test-user-123', title: 'Updated Title', category: 'Home Insurance', filePaths: [], createdAt: amplify_core.TemporalDateTime.now(, lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 2,
        syncState: SyncState.synced.toJson(),
      );

      // Documents with same sync identifier should be considered the same logical document
      expect(document1.syncId, equals(document2.syncId));

      // But they can have different content and versions
      expect(document1.title, isNot(equals(document2.title)));
      expect(document1.version, isNot(equals(document2.version)));
      expect(document1.syncState, isNot(equals(document2.syncState)));
    });

    test('Document should handle missing sync identifier gracefully', () {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        // No syncId provided
        userId: 'test-user-123',
        title: 'Test Document',
        category: 'Home Insurance',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      // Document should be created but without sync identifier
      expect(document.syncId, isNull);
      expect(document.title, equals('Test Document'));
    });
  });
}
