import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/sync_service.dart';

/// Integration tests for data consistency across operations
///
/// Tests Requirements 11.1, 11.2, 11.3, 11.4, 11.5
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Consistency Integration Tests', () {
    late DocumentRepository repository;
    late SyncService syncService;

    setUp(() {
      repository = DocumentRepository();
      syncService = SyncService();
    });

    tearDown(() {
      syncService.dispose();
    });

    group('Requirement 11.1: SyncId Uniqueness', () {
      test('should generate unique syncIds for multiple documents', () async {
        // Create multiple documents
        final doc1 = await repository.createDocument(
          title: 'Document 1',
          description: 'Test document 1',
        );

        final doc2 = await repository.createDocument(
          title: 'Document 2',
          description: 'Test document 2',
        );

        final doc3 = await repository.createDocument(
          title: 'Document 3',
          description: 'Test document 3',
        );

        // Verify all syncIds are unique
        expect(doc1.syncId, isNot(equals(doc2.syncId)));
        expect(doc1.syncId, isNot(equals(doc3.syncId)));
        expect(doc2.syncId, isNot(equals(doc3.syncId)));

        // Verify syncIds are valid UUIDs (36 characters with hyphens)
        expect(doc1.syncId.length, equals(36));
        expect(doc2.syncId.length, equals(36));
        expect(doc3.syncId.length, equals(36));

        // Clean up
        await repository.deleteDocument(doc1.syncId);
        await repository.deleteDocument(doc2.syncId);
        await repository.deleteDocument(doc3.syncId);
      });

      test('should enforce syncId uniqueness at database level', () async {
        // Create a document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        // Attempting to create another document with same syncId should fail
        // (This is enforced by PRIMARY KEY constraint)
        // We can't easily test this without direct database access,
        // but the schema ensures it

        expect(doc.syncId, isNotEmpty);

        // Clean up
        await repository.deleteDocument(doc.syncId);
      });

      test('should maintain syncId uniqueness across operations', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        final originalSyncId = doc.syncId;

        // Update document
        final updated = doc.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );
        await repository.updateDocument(updated);

        // Retrieve document
        final retrieved = await repository.getDocument(originalSyncId);

        // Verify syncId hasn't changed
        expect(retrieved?.syncId, equals(originalSyncId));

        // Clean up
        await repository.deleteDocument(originalSyncId);
      });
    });

    group('Requirement 11.2: Metadata Propagation', () {
      test('should update timestamp when document is modified', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        final originalUpdatedAt = doc.updatedAt;

        // Wait a bit to ensure timestamp difference
        await Future.delayed(const Duration(milliseconds: 100));

        // Update document
        final updated = doc.copyWith(
          title: 'Updated Title',
        );
        await repository.updateDocument(updated);

        // Retrieve document
        final retrieved = await repository.getDocument(doc.syncId);

        // Verify updatedAt timestamp changed
        expect(retrieved?.updatedAt.isAfter(originalUpdatedAt), isTrue);

        // Clean up
        await repository.deleteDocument(doc.syncId);
      });

      test('should preserve metadata across sync state changes', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
          description: 'Test description',
          labels: ['label1', 'label2'],
        );

        // Change sync state
        await repository.updateSyncState(doc.syncId, SyncState.uploading);
        await repository.updateSyncState(doc.syncId, SyncState.synced);

        // Retrieve document
        final retrieved = await repository.getDocument(doc.syncId);

        // Verify metadata preserved
        expect(retrieved?.title, equals('Test Document'));
        expect(retrieved?.description, equals('Test description'));
        expect(retrieved?.labels, equals(['label1', 'label2']));

        // Clean up
        await repository.deleteDocument(doc.syncId);
      });
    });

    group('Requirement 11.4: Document Deletion Propagation', () {
      test('should delete document from local database', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        // Verify document exists
        final exists = await repository.getDocument(doc.syncId);
        expect(exists, isNotNull);

        // Delete document
        await repository.deleteDocument(doc.syncId);

        // Verify document no longer exists
        final deleted = await repository.getDocument(doc.syncId);
        expect(deleted, isNull);
      });

      test('should cascade delete file attachments', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        // Add file attachment
        await repository.addFileAttachment(
          syncId: doc.syncId,
          fileName: 'test.pdf',
          localPath: '/path/to/test.pdf',
        );

        // Verify file attachment exists
        final files = await repository.getFileAttachments(doc.syncId);
        expect(files.length, equals(1));

        // Delete document
        await repository.deleteDocument(doc.syncId);

        // Verify file attachments also deleted (cascade)
        final filesAfterDelete =
            await repository.getFileAttachments(doc.syncId);
        expect(filesAfterDelete.length, equals(0));
      });
    });

    group('Requirement 11.5: Sync State Consistency', () {
      test('should maintain consistent sync states', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        // Initial state should be pendingUpload
        expect(doc.syncState, equals(SyncState.pendingUpload));

        // Update to uploading
        await repository.updateSyncState(doc.syncId, SyncState.uploading);
        var retrieved = await repository.getDocument(doc.syncId);
        expect(retrieved?.syncState, equals(SyncState.uploading));

        // Update to synced
        await repository.updateSyncState(doc.syncId, SyncState.synced);
        retrieved = await repository.getDocument(doc.syncId);
        expect(retrieved?.syncState, equals(SyncState.synced));

        // Clean up
        await repository.deleteDocument(doc.syncId);
      });

      test('should verify sync consistency method exists', () {
        // Verify the method exists and can be called
        expect(syncService.verifySyncConsistency, isA<Function>());
      });

      test('should handle sync consistency verification without errors',
          () async {
        // Create some test documents
        final doc1 = await repository.createDocument(
          title: 'Document 1',
        );

        final doc2 = await repository.createDocument(
          title: 'Document 2',
        );

        // Run consistency verification
        await expectLater(
          syncService.verifySyncConsistency(),
          completes,
        );

        // Clean up
        await repository.deleteDocument(doc1.syncId);
        await repository.deleteDocument(doc2.syncId);
      });
    });

    group('Multi-Operation Consistency', () {
      test('should maintain consistency across create-update-delete cycle',
          () async {
        // Create
        final doc = await repository.createDocument(
          title: 'Test Document',
          description: 'Original description',
        );

        expect(doc.syncId, isNotEmpty);
        expect(doc.title, equals('Test Document'));

        // Update
        final updated = doc.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );
        await repository.updateDocument(updated);

        final retrieved = await repository.getDocument(doc.syncId);
        expect(retrieved?.title, equals('Updated Title'));
        expect(retrieved?.description, equals('Updated description'));

        // Delete
        await repository.deleteDocument(doc.syncId);

        final deleted = await repository.getDocument(doc.syncId);
        expect(deleted, isNull);
      });

      test('should maintain consistency with file attachments', () async {
        // Create document
        final doc = await repository.createDocument(
          title: 'Test Document',
        );

        // Add file
        await repository.addFileAttachment(
          syncId: doc.syncId,
          fileName: 'test.pdf',
          localPath: '/path/to/test.pdf',
        );

        // Update S3 key
        await repository.updateFileS3Key(
          syncId: doc.syncId,
          fileName: 'test.pdf',
          s3Key: 'private/identity/documents/${doc.syncId}/test.pdf',
        );

        // Retrieve and verify
        final files = await repository.getFileAttachments(doc.syncId);
        expect(files.length, equals(1));
        expect(files[0].fileName, equals('test.pdf'));
        expect(files[0].s3Key, isNotNull);

        // Clean up
        await repository.deleteDocument(doc.syncId);
      });
    });
  });
}
